# you may need to modify RUBYPATH. And I don't know why I had to change to the directory (the install was complaining about missing files)
echo First make sure you have Jruby installed. It must be Ruby 2\ or later-- the Ubuntu 16.04 jruby will not work. It must also be a system-wide installation if you want to set up the service. Once you are sure it is installed, modify this installer to include the jruby path in RUBYPATH.
export RUBYPATH=/usr/share/rvm/rubies/jruby-9.2.0.0 
cd $RUBYPATH/bin 
sudo ./jruby -S gem install json
sudo ./jruby -S gem install manticore
sudo ./jruby -S gem install device_input

