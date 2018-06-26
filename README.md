# Installing youtube-viewer and gtk-youtube-viewer on Ubuntu 18.04

## Dependencies
youtube-viewer has some packages that are required for it to work so install these things:
```
sudo apt install git libncurses5-dev libtinfo-dev libreadline-dev pkg-config libgtk2.0-dev libcanberra-gtk-module
```
## Installing
```
cd /tmp
git clone https://github.com/trizen/youtube-viewer     
cd youtube-viewer
sudo cpan install CPAN ExtUtils::PkgConfig Module::Build inc::latest PAR::Dist Term::ReadLine::Gnu::XS Unicode::GCString LWP::Protocol::https Data::Dump JSON Gtk2 File::ShareDir
perl Build.PL --gtk
sudo ./Build installdeps
sudo ./Build install
```
### youtube-viewer

* command-line interface to YouTube.

![youtube-viewer](https://user-images.githubusercontent.com/614513/32416613-c3daa6a6-c254-11e7-9739-ed7bf93d188c.png)

### gtk-youtube-viewer

* GTK2 interface to YouTube.

![gtk-youtube-viewer](https://user-images.githubusercontent.com/614513/32453099-10d14b3e-c324-11e7-942b-13a38c424341.png)
