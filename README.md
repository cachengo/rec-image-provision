This project contains dracut modules. They are used for provisioning image from a boot CD.  
This RPM is installed in image.  
During RPM post dracut command is run to generate a provisioning initramfs.  
There are also Dracut modules which support reading configuration from Floppy/DVD header.  
It is also capable of configuring network, and fetcing Production CD over Network (instead of iLO), making CI runs faster.

