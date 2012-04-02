action :configure do 
  bash "configure for openstack" do
    flags "-ex"
    code <<-EOH
      guest_root=#{guest_root}

      case "#{node[:rightimage][:platform]}" in
      "centos")
        # clean out packages
        chroot $guest_root yum -y clean all

        # clean centos RPM data
        rm ${guest_root}/var/lib/rpm/__*
        chroot $guest_root rpm --rebuilddb

        # enable console access
        echo "2:2345:respawn:/sbin/mingetty tty2" >> $guest_root/etc/inittab
        echo "tty2" >> $guest_root/etc/securetty

        # configure dhcp timeout
        echo 'timeout 300;' > $guest_root/etc/dhclient.conf

        [ -f $guest_root/var/lib/rpm/__* ] && rm ${guest_root}/var/lib/rpm/__*
        chroot $guest_root rpm --rebuilddb
        ;;
      "ubuntu")
        # Disable all ttys except for tty1 (console)
        for i in `ls $guest_root/etc/init/tty[2-9].conf`; do
          mv $i $i.disabled;
        done
        ;;
      esac

      # set hwclock to UTC
      echo "UTC" >> $guest_root/etc/adjtime
    EOH
  end
end


action :upload do
  package "python2.6-dev" do
    only_if { node[:platform] == "ubuntu" }
    action :install
  end

  package "python-setuptools" do
    only_if { node[:platform] == "ubuntu" }
    action :install
  end

  bash "install python modules" do
    flags "-ex"
    code <<-EOH
      easy_install-2.6 sqlalchemy eventlet routes webob paste pastedeploy glance argparse xattr httplib2 kombu iso8601
    EOH
  end

  ruby_block "upload to cloud" do
    block do
      require 'json'
      filename = "#{image_name}.qcow2"
      local_file = "#{target_temp_root}/#{filename}"

      openstack_user = node[:rightimage][:openstack][:user]
      openstack_password = node[:rightimage][:openstack][:password]
      openstack_host = node[:rightimage][:openstack][:hostname].split(":")[0]
      openstack_api_port = node[:rightimage][:openstack][:hostname].split(":")[1] || "5000"
      openstack_glance_port = "9292"

      Chef::Log.info("Getting openstack api token for user #{openstack_user}@#{openstack_host}:#{openstack_api_port}")
      auth_resp = `curl -d '{"auth":{"passwordCredentials":{"username": "#{openstack_user}", "password": "#{openstack_password}"}}}' -H "Content-type: application/json" http://#{openstack_host}:#{openstack_api_port}/v2.0/tokens` 
      Chef::Log.info("got response for auth req: #{auth_resp}")
      auth_hash = JSON.parse(auth_resp)
      access_token = auth_hash["access"]["token"]["id"]

      # Don't use location=file://path/to/file like you might think, thats the name of the location to store the file on the server that hosts the images, not this machine
      cmd = %Q(env PATH=$PATH:/usr/local/bin glance add --auth_token=#{access_token} --url=http://#{openstack_host}:#{openstack_glance_port}/v2.0 name=#{image_name} is_public=true disk_format=qcow2 container_format=ovf < #{local_file})
      Chef::Log.debug(cmd)
      upload_resp = `#{cmd}`
      Chef::Log.info("got response for upload req: #{upload_resp} to cloud.")

      if upload_resp =~ /added/i 
        image_id = upload_resp.scan(/ID:\s(\d+)/i).first
        Chef::Log.info("Successfully uploaded image #{image_id} to cloud.")
        
        # add to global id store for use by other recipes
        id_list = RightImage::IdList.new(Chef::Log)
        id_list.add(image_id)
      else
        raise "ERROR: could not upload image to cloud at #{node[:rightimage][:openstack][:hostname]} due to #{upload_resp.inspect}"
      end
    end
  end
end