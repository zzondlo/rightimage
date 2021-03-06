## when pasting a key into a json file, make sure to use the following command: 
## sed -e :a -e '$!N;s/\n/\\n/;ta' /path/to/key
## this seems not to work on os x
class Chef::Node
 include RightScale::RightImage::Helper
end
UNKNOWN = :unknown.to_s

set_unless[:rightimage][:debug] = false
set[:rightimage][:lang] = "en_US.UTF-8"
set_unless[:rightimage][:root_size_gb] = "10"
set[:rightimage][:build_dir] = "/mnt/vmbuilder"
set[:rightimage][:mount_dir] = "/mnt/image"
set_unless[:rightimage][:virtual_environment] = "xen"
set[:rightimage][:mirror] = "cf-mirror.rightscale.com"
set_unless[:rightimage][:sandbox_repo_tag] = "rightlink_package_#{rightimage[:rightlink_version]}"
set_unless[:rightimage][:cloud] = "raw"
set[:rightimage][:root_mount][:label_dev] = "ROOT"
set[:rightimage][:root_mount][:dev] = "LABEL=#{rightimage[:root_mount][:label_dev]}"
set_unless[:rightimage][:image_source_bucket] = "rightscale-us-west-2"

if rightimage[:platform] == "ubuntu"
  set[:rightimage][:mirror_date] = "#{timestamp[0..3]}/#{timestamp[4..5]}/#{timestamp[6..7]}"
  set[:rightimage][:mirror_url] = "http://#{node[:rightimage][:mirror]}/ubuntu_daily/#{node[:rightimage][:mirror_date]}"
else
  set[:rightimage][:mirror_date] = timestamp[0..7]
end

# set base os packages
case rightimage[:platform]
when "ubuntu"   
  set[:rightimage][:guest_packages] = "ubuntu-standard binutils ruby1.8 curl unzip openssh-server ruby1.8-dev build-essential autoconf automake libtool logrotate rsync openssl openssh-server ca-certificates libopenssl-ruby1.8 subversion vim libreadline-ruby1.8 irb rdoc1.8 git-core liberror-perl libdigest-sha1-perl dmsetup emacs rake screen mailutils nscd bison ncurses-dev zlib1g-dev libreadline5-dev readline-common libxslt1-dev sqlite3 libxml2 libxml2-dev flex libshadow-ruby1.8 postfix sysstat iptraf syslog-ng libarchive-dev tmux"

  node[:rightimage][:guest_packages] << " cloud-init" if node[:rightimage][:virtual_environment] == "ec2"
  set[:rightimage][:host_packages] = "openjdk-6-jre openssl ca-certificates"

  case node[:lsb][:codename]
    when "maverick"
      rightimage[:host_packages] << " apt-cacher"
    else
      rightimage[:host_packages] << " apt-proxy"
  end

  set[:rightimage][:package_type] = "deb"
  rightimage[:guest_packages] << " euca2ools" if rightimage[:cloud] == "euca"

when "centos","rhel"
  set[:rightimage][:guest_packages] = "wget mlocate nano logrotate ruby ruby-devel ruby-docs ruby-irb ruby-libs ruby-mode ruby-rdoc ruby-ri ruby-tcltk postfix openssl openssh openssh-askpass openssh-clients openssh-server curl gcc* zip unzip bison flex compat-libstdc++-296 cvs subversion autoconf automake libtool compat-gcc-34-g77 mutt sysstat rpm-build fping vim-common vim-enhanced rrdtool-1.2.27 rrdtool-devel-1.2.27 rrdtool-doc-1.2.27 rrdtool-perl-1.2.27 rrdtool-python-1.2.27 rrdtool-ruby-1.2.27 rrdtool-tcl-1.2.27 pkgconfig lynx screen yum-utils bwm-ng createrepo redhat-rpm-config redhat-lsb git nscd xfsprogs swig libarchive-devel tmux libxml2 libxml2-devel libxslt libxslt-devel"

  rightimage[:guest_packages] << " iscsi-initiator-utils" if rightimage[:cloud] == "vmops" 

  set[:rightimage][:host_packages] = "swig"
  set[:rightimage][:package_type] = "rpm"
when "suse"
  set[:rightimage][:guest_packages] = "gcc"

  set[:rightimage][:host_packages] = "kiwi"
end

# set addtional release specific packages
case rightimage[:release]
  when "hardy"
    set[:rightimage][:guest_packages] = rightimage[:guest_packages] + " sysv-rc-conf debian-helper-scripts"
    rightimage[:host_packages] << " ubuntu-vm-builder"
  when "karmic"
    rightimage[:host_packages] << " python-vm-builder-ec2"
  when "lucid"
    if rightimage[:cloud] == "ec2"
      rightimage[:host_packages] << " python-vm-builder-ec2 devscripts"
    else
      rightimage[:host_packages] << " devscripts"
    end
  when "maverick"
    rightimage[:host_packages] << " devscripts"
end if rightimage[:platform] == "ubuntu" 

# set cloud stuff
case rightimage[:cloud]
  when "ec2", "euca" 
    set[:rightimage][:root_mount][:dump] = "0" 
    set[:rightimage][:root_mount][:fsck] = "0" 
    set[:rightimage][:fstab][:ephemeral] = true
    # Might have to double check don't know if maverick should use kernel linux-image-ec2 or not
    if rightimage[:platform] == "ubuntu" and rightimage[:release_number].to_f >= 10.10
      set[:rightimage][:ephemeral_mount] = "/dev/xvdb" 
    else
      set[:rightimage][:ephemeral_mount] = "/dev/sdb" 
    end
    set[:rightimage][:swap_mount] = "/dev/sda3"  unless rightimage[:arch]  == "x86_64"
    case rightimage[:platform]
      when "ubuntu" 
        set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults,nobootwait"
        set[:rightimage][:fstab][:swap] = "defaults,nobootwait"
      when "centos", "rhel"
        set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults"
        set[:rightimage][:fstab][:swap] = "defaults"
    end
  when "vmops", "openstack"
    rightimage[:host_packages] << " python26-distribute python26-devel python26-libs" if rightimage[:cloud] == "openstack"

    case rightimage[:virtual_environment]
    when "xen"
      set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults"
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
      set[:rightimage][:ephemeral_mount] = nil
      set[:rightimage][:fstab][:ephemeral_mount_opts] = nil
    when "kvm"
      rightimage[:host_packages] << " qemu grub"
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:ephemeral_mount] = "/dev/vdb"
      set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults"
      set[:rightimage][:grub][:root_device] = "/dev/vda"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    when "esxi"
      rightimage[:host_packages] << " qemu grub"
      set[:rightimage][:ephemeral_mount] = nil
      set[:rightimage][:fstab][:ephemeral_mount_opts] = nil
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:grub][:root_device] = "/dev/sda"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    else
      raise "ERROR: unsupported virtual_environment #{node[:rightimage][:virtual_environment]} for cloudstack"
    end
end


# set rightscale stuff
set_unless[:rightimage][:rightlink_version] = ""
set_unless[:rightimage][:aws_access_key_id] = nil
set_unless[:rightimage][:aws_secret_access_key] = nil

# generate command to install getsshkey init script 
case rightimage[:platform]
  when "ubuntu" 
    set[:rightimage][:getsshkey_cmd] = "chroot $GUEST_ROOT update-rc.d getsshkey start 20 2 3 4 5 . stop 1 0 1 6 ."
    set[:rightimage][:mirror_file] = "sources.list.erb"
    set[:rightimage][:mirror_file_path] = "/etc/apt/sources.list"
  when "centos", "rhel"
    set[:rightimage][:getsshkey_cmd] = "chroot $GUEST_ROOT chkconfig --add getsshkey && \
               chroot $GUEST_ROOT chkconfig --level 4 getsshkey on"
    set[:rightimage][:mirror_file] = "CentOS.repo.erb"
    set[:rightimage][:mirror_file_path] = "/etc/yum.repos.d/CentOS.repo"
  when UNKNOWN

end

# set default EC2 endpoint
case rightimage[:region]
  when "us-east"
    set[:rightimage][:ec2_endpoint] = "https://ec2.us-east-1.amazonaws.com"
  when "us-west"
    set[:rightimage][:ec2_endpoint] = "https://ec2.us-west-1.amazonaws.com"
  when "us-west-2"
    set[:rightimage][:ec2_endpoint] = "https://ec2.us-west-2.amazonaws.com"
  when "eu-west"
    set[:rightimage][:ec2_endpoint] = "https://ec2.eu-west-1.amazonaws.com"
  when "ap-southeast"
    set[:rightimage][:ec2_endpoint] = "https://ec2.ap-southeast-1.amazonaws.com"
  when "ap-northeast"
    set[:rightimage][:ec2_endpoint] = "https://ec2.ap-northeast-1.amazonaws.com"
  when "sa-east"
    set[:rightimage][:ec2_endpoint] = "https://ec2.sa-east-1.amazonaws.com"
  else
    set[:rightimage][:ec2_endpoint] = "https://ec2.us-east-1.amazonaws.com"
end #if rightimage[:cloud] == "ec2" 

# if ubuntu then figure out the numbered name
set[:rightimage][:release_number] = release_number


# Select kernel to use based on cloud
#case rightimage[:cloud]
#when "vmops", "euca", "openstack"
case rightimage[:release]
when "5.2" 
  set[:rightimage][:kernel_id] = "2.6.18-92.1.22.el5.centos.plus"
  rightimage[:kernel_id] << "xen" if rightimage[:virtual_environment] == "xen"
when "5.4" 
  set[:rightimage][:kernel_id] = "2.6.18-164.15.1.el5.centos.plus"
  rightimage[:kernel_id] << "xen" if rightimage[:virtual_environment] == "xen"
when "5.6"
  set[:rightimage][:kernel_id] = "2.6.18-238.19.1.el5.centos.plus"
  rightimage[:kernel_id] << "xen" if rightimage[:virtual_environment] == "xen"
when "lucid"
  set[:rightimage][:kernel_id] = "2.6.32-31-server"
  rightimage[:kernel_id] << "kvm" if rightimage[:virtual_environment] == "kvm"
  #rightimage[:kernel_id] << "esxi" if rightimage[:virtual_environment] == "esxi"
end

case rightimage[:cloud]
when "ec2"
  # Using pvgrub kernels
  case rightimage[:region]
  when "us-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-805ea7e9"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-825ea7eb"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-83396bc6"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-8d396bc8"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "eu-west" 
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-64695810"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-62695816"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-southeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-a4225af6"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-aa225af8"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "ap-northeast"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-ec5df7ed"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-ee5df7ef"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "us-west-2"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-c2e26ff2"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-98e26fa8"
      set[:rightimage][:ramdisk_id] = nil
    end
  when "sa-east"
    case rightimage[:arch]
    when "i386" 
      set[:rightimage][:aki_id] = "aki-bc3ce3a1"
      set[:rightimage][:ramdisk_id] = nil
    when "x86_64"
      set[:rightimage][:aki_id] = "aki-cc3ce3d1"
      set[:rightimage][:ramdisk_id] = nil
    end
  end
end # case rightimage[:cloud]
