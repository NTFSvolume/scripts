sudo apt install automake bsudo apt install automake build-essential pkg-config libevent-dev libncurses-dev -y 
VERSION=3.4
wget https://github.com/tmux/tmux/releases/download/${VERSION}/tmux-${VERSION}.tar.gz 
tar xf tmux-${VERSION}.tar.gz 
rm tmux-${VERSION}.tar.gz 
cd tmux-${VERSION} 
./configure 
make 
sudo make install 
sudo killall -9 tmux