# Copyright 2013. The Regents of the University of California.
# All rights reserved. Use of this source code is governed by 
# a BSD-style license which can be found in the LICENSE file.


# silent make
#MAKEFLAGS += --silent

# use for parallel make
#AR=./ar_lock.sh

CUDA=0
ACML=0
GSL=1
OMP=1
SLINK=0

BUILDTYPE = Linux
UNAME = $(shell uname -s)
NNAME = $(shell uname -n)

MYLINK=ln

ifeq ($(UNAME),Darwin)
	BUILDTYPE = MacOSX
	ACML = 0
	MYLINK = ln -s
endif

ARFLAGS = r


# Paths

here  = $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
root := $(here)

srcdir = $(root)/src
libdir = $(root)/lib
bindir = $(root)/bin

export TOOLBOX_PATH=$(root)


# Automatic dependency generation

DEPFILE = $(*D)/.$(*F).d
DEPFLAG = -MMD -MF $(DEPFILE)
ALLDEPS = $(shell find $(srcdir) -name ".*.d")


# Compilation flags

OPT = -O3 -ffast-math
CPPFLAGS = $(DEPFLAG) -Wall -Wextra -I$(srcdir)/
CFLAGS = $(OPT) -std=c99 -Wmissing-prototypes -I$(srcdir)/
CXXFLAGS = $(OPT) -I$(srcdir)/
CC = gcc
CXX = g++


ifeq ($(BUILDTYPE), MacOSX)
	CC = gcc-mp-4.7
endif


# cuda

cuda.top := /usr/

# GSL

gsl.top := /usr/

ifeq ($(BUILDTYPE), MacOSX)
gsl.top = /opt/local
endif

# BLAS/LAPACK

acml.top := /usr/local/acml/acml4.4.0/gfortran64_mp/

# fftw

fftw.top := /usr/

# Matlab

matlab.top := /usr/local/matlab/

# ISMRM

ismrm.top := /usr/local/ismrmrd/





# Main build targets

TBASE=slice crop resize join transpose zeros ones flip circshift extract repmat bitmask
TFLP=scale conj fmac saxpy sdot spow cpyphs creal normalize cdf97
TNUM=fft fftmod noise bench threshold conv
TRECO=sense pocsense rsense bpsense itsense nlinv nufft rof nusense sake
TCALIB=ecalib caldir walsh cc calmat svd
TMRI=rss homodyne pattern poisson twixread
TSIM=phantom traj
BTARGETS = $(TBASE) $(TFLP) $(TNUM)
XTARGETS = bart $(TRECO) $(TCALIB) $(TMRI) $(TSIM)
TARGETS = $(BTARGETS) $(XTARGETS)





MODULES = -lnum -lmisc -lnum -lmisc

MODULES_sense = -lsense -lwavelet2 -liter -llinops -lwavelet3 -llowrank
MODULES_nusense = -lsense -lwavelet2 -lnoncart -liter -llinops
MODULES_pocsense = -lsense -lwavelet2 -liter -llinops
MODULES_nlinv = -lnoir -liter
MODULES_rsense = -lgrecon -lsense -lnoir -lwavelet2 -lcalib -liter -llinops
MODULES_bpsense = -lsense -lwavelet2 -lnoncart -liter -llinops
MODULES_itsense = -liter -llinops
MODULES_ecalib = -lcalib
MODULES_caldir = -lcalib
MODULES_walsh = -lcalib
MODULES_calmat = -lcalib
MODULES_cc = -lcalib
MODULES_nufft = -lnoncart -liter -llinops
MODULES_rof = -liter -llinops
MODULES_bench = -lwavelet2 -lwavelet3 -llinops
MODULES_phantom = -lsimu
MODULES_bart += -lbox -lwavelet2 -lwavelet3 -llinops
MODULES_sake += -lsake


-include Makefile.$(NNAME)
-include Makefile.local





ifeq ($(PARALLEL),1)
.PHONY: all $(MAKECMDGOALS)
all $(MAKECMDGOALS):
	echo Parallel build.
	make PARALLEL=2 -j $(MAKECMDGOALS)
else


default: all


-include $(ALLDEPS)




# cuda

NVCC = $(cuda.top)/bin/nvcc


ifeq ($(CUDA),1)
CUDA_H := -I$(cuda.top)/include
CPPFLAGS += -DUSE_CUDA $(CUDA_H)
ifeq ($(BUILDTYPE), MacOSX)
CUDA_L := -L$(cuda.top)/lib -lcufft -lcudart -lcublas -lcuda -m64 -lstdc++
else
CUDA_L := -L$(cuda.top)/lib64 -lcufft -lcudart -lcublas -lcuda -lstdc++
endif 
else
CUDA_H :=
CUDA_L :=  
endif

NVCCFLAGS = -DUSE_CUDA -Xcompiler -fPIC -Xcompiler -fopenmp -O3 -arch=sm_20 -I$(srcdir)/ -m64 -ccbin $(CC)
#NVCCFLAGS = -Xcompiler -fPIC -Xcompiler -fopenmp -O3  -I$(srcdir)/


%.o: %.cu
	$(NVCC) $(NVCCFLAGS) -c $^ -o $@
	$(NVCC) $(NVCCFLAGS) -M $^ -o $(DEPFILE)


# OpenMP

ifeq ($(OMP),1)
CFLAGS += -fopenmp
CXXFLAGS += -fopenmp
else
CFLAGS += -Wno-unknown-pragmas
CXXFLAGS += -Wno-unknown-pragmas
endif



# GSL

ifeq ($(BUILDTYPE), MacOSX)
GSL_H := -I$(gsl.top)/include
GSL_L := -L$(gsl.top)/lib -lgsl -lgslcblas
else
GSL_H := 
GSL_L := -lgsl -lgslcblas
endif

ifeq ($(GSL),1)
CPPFLAGS += -DUSE_GSL $(GSL_H) $(BLAS_H)
endif


# BLAS/LAPACK

BLAS_H :=
BLAS_L :=

ifeq ($(ACML),1)
BLAS_H := -I$(acml.top)/include
BLAS_L := -L$(acml.top)/lib -lgfortran -lacml_mp -Wl,-rpath $(acml.top)/lib
CPPFLAGS += -DUSE_ACML
else
ifeq ($(BUILDTYPE), MacOSX)
BLAS_L := -lblas -framework Accelerate
else
BLAS_L := -llapack -lblas #-lgfortran
endif
endif



# png
PNG_L := #-lpng -lz


# fftw

FFTW_H := -I$(fftw.top)/include/
FFTW_L := -L$(fftw.top)/lib -lfftw3f_threads -lfftw3f


# Matlab

MATLAB_H := -I$(matlab.top)/extern/include
MATLAB_L := -Wl,-rpath $(matlab.top)/bin/glnxa64 -L$(matlab.top)/bin/glnxa64 -lmat -lmx -lm -lstdc++

# ISMRM

ISMRM_H := -I$(ismrm.top)/include -I$(ismrm.top)/schema #-DISMRMRD_OLD
ISMRM_L := /usr/local/ismrmrd/schema/ismrmrd.cxx -Wl,-R$(ismrm.top)/lib -L$(ismrm.top)/lib -lismrmrd -Lhd5 -lxerces-c -lboost_system
#ISMRM_L := -Wl,-R$(ismrm.top)/lib -L$(ismrm.top)/lib -lismrmrd -lismrmrd_xsd -Lhd5 



# change for static linking

ifeq ($(SLINK),1)
# work around fortran problems with static linking
LDFLAGS += -static -Wl,--whole-archive -lpthread -Wl,--no-whole-archive -Wl,--allow-multiple-definition
ifneq ($(BUILDTYPE), MacOSX)
BLAS_L += -lgfortran
endif
endif



# Modules

#.LIBPATTERNS := lib/lib%.a


vpath %.a lib

DIRS = $(root)/rules/*.mk

include $(DIRS)


all: $(TARGETS)





# special targets


bart: CPPFLAGS += -DMAIN_LIST="$(BTARGETS:%=%,) ()"


ismrmrd: $(srcdir)/ismrmrd.c -lismrm -lnum -lmisc
	$(CC) $(CXXFLAGS) -o ismrmrd $+ $(CUDA_L) $(ISMRM_L) -lstdc++ -lm

mat2cfl: $(srcdir)/mat2cfl.c -lnum -lmisc
	$(CC) $(CFLAGS) $(MATLAB_H) -omat2cfl  $+ $(MATLAB_L) $(CUDA_L)


$(BTARGETS): bart
	rm -f $@ && $(MYLINK) bart $@


.SECONDEXPANSION:
$(XTARGETS): % : $(srcdir)/%.c $$(MODULES_%) $(MODULES)
	$(CC) $(LDFLAGS) $(CPPFLAGS) $(CFLAGS) -Dmain_$@=main -o $@ $+ $(FFTW_L) $(CUDA_L) $(BLAS_L) $(GSL_L) $(PNG_L) -lm
#	rm $(srcdir)/$@.o


.PHONY: clean allclean
clean:
	rm -f `find $(srcdir) -name "*.o"`

allclean: clean
	rm -f $(libdir)/*.a $(TARGETS) ismrmrd $(ALLDEPS)



endif	#PARALLEL


