# -*- mode: ruby -*-


# This is so I can spin up a bunch of additional low-powered VMs to practice
# with if I want to simulate having more Pi's than I do.


# Specify non-default provider
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'

# Misc other stuff that helps things
ENV['CONFIGURE_ARGS'] = '--use-system-libraries=true --with-xml2-include=/usr/include/libxml2'


Vagrant.require_version ">= 1.7.0"

Vagrant.configure("2") do |config|

  config.vm.define "archvagrant1" do |archvagrant1|
    archvagrant1.vm.box = "archlinux/archlinux"
    archvagrant1.vm.box_check_update = false
    archvagrant1.vm.network "public_network", type: "dhcp", bridge: 'wlp1s0f0u2u2'
    archvagrant1.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
    end
    archvagrant1.vm.hostname = "archvagrant1"
  end

  config.vm.define "archvagrant2" do |archvagrant2|
    archvagrant2.vm.box = "archlinux/archlinux"
    archvagrant2.vm.box_check_update = false
    archvagrant2.vm.network "public_network", type: "dhcp", bridge: 'wlp1s0f0u2u2'
    archvagrant2.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
    end
    archvagrant2.vm.hostname = "archvagrant2"
  end

  config.vm.define "archvagrant3" do |archvagrant3|
    archvagrant3.vm.box = "archlinux/archlinux"
    archvagrant3.vm.box_check_update = false
    archvagrant3.vm.network "public_network", type: "dhcp", bridge: 'wlp1s0f0u2u2'
    archvagrant3.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
    end
    archvagrant3.vm.hostname = "archvagrant3"
  end

  config.vm.define "archvagrant4" do |archvagrant4|
    archvagrant4.vm.box = "archlinux/archlinux"
    archvagrant4.vm.box_check_update = false
    archvagrant4.vm.network "public_network", type: "dhcp", bridge: 'wlp1s0f0u2u2'
    archvagrant4.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
    end
    archvagrant4.vm.hostname = "archvagrant4"
  end

end

