# merit-miner-install

## Merit (MRT) Miner Installation Script

This is an installation script for mining Merit (MRT).  I made this script primarily for my own personal use.

This install script is based on the Syscoin Masternode install script, which in turn was based on the Bulwark masternode install script created by the [Bulwark team](https://github.com/bulwark-crypto/Bulwark-MN-Install)

The install procedure is mostly based on this the Merit website instructions (https://www.merit.me/get-started/) with some enhancements included.

To fix the locale settings on your VPS, you may want to run the following before running the Install Script:

```bash <( curl https://raw.githubusercontent.com/akriv-git/merit-miner-install/master/fix-locale.sh )```

To install your miner, issue the following command on your VPS:

```bash <( curl https://raw.githubusercontent.com/akriv-git/merit-miner-install/master/mrt-mnr-build.sh )```

Have Fun!
