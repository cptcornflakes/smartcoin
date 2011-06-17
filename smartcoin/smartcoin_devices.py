#!/usr/bin/python
import pyopencl as cl

platforms = cl.get_platforms()
devices = platforms[-1].get_devices()
for i in xrange(len(devices)):
	print '[%d]%s' % (i, devices[i].name)
