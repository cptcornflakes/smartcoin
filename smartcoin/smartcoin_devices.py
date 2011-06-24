#!/usr/bin/python
import pyopencl as cl

platforms = cl.get_platforms()
devices = platforms[-1].get_devices()
for i in xrange(len(devices)):
	if "CPU" in devices[i].name:
		print '%d\tCPU[%d]\t1\tcpu' % (i,i) 
	else:
		print '%d\tGPU[%d]\t0\tcpu' % (i,i)



