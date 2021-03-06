## This is an automake file, part of Unidata's netCDF package.
# Copyright 2005-2006, see the COPYRIGHT file for more information.

# This file controls the building of the fortran 90 API. All testing
# of the F90 API is done in the nf_test directory.

# The F90 library is always built as a convenience library. It is
# included by the netCDF-4 library in libsrc4, or the netCDF-3 library
# in libsrc, or the separate fortran library in fortran.

# $Id: Makefile.am,v 1.39 2008/04/28 13:20:08 ed Exp $

# This is the F90 API man page.
man_MANS = netcdf_f90.3
EXTRA_DIST = $(man_MANS)

# This, plus either netcdf4.f90 or netcdf.f90, is the main source.
libnetcdff90_la_SOURCES = typeSizes.f90 

# The file netcdf.f90 includes all of these.
libnetcdff90_la_DEPENDENCIES = netcdf_attributes.f90			\
netcdf_constants.f90 netcdf_dims.f90 netcdf_expanded.f90		\
netcdf_externals.f90 netcdf_file.f90 netcdf_overloads.f90		\
netcdf_text_variables.f90 netcdf_variables.f90 netcdf_visibility.f90

# Is the user building netCDF-4?
if USE_NETCDF4

# Point the fortran compiler at netcdf-4 directory (libsrc4) and the
# current dir.
AM_FCFLAGS = -I$(top_srcdir)/libsrc4 -I$(srcdir)

# Use netcdf4.f90 to build the library.
libnetcdff90_la_SOURCES += netcdf4.f90 

# These are the extra netCDF-4 F90 source files.
libnetcdff90_la_DEPENDENCIES += netcdf4_func.f90 netcdf4_externals.f90	\
netcdf4_visibility.f90 netcdf4_constants.f90 netcdf4.f90

NETCDF_O = netcdf4.o

else # not USE_NETCDF4

# Point the preprocessor at the netcdf-3 directory (libsrc).
AM_FCFLAGS = -I$(top_srcdir)/libsrc -I$(srcdir)

# Use netcdf.f90 to get the library.
libnetcdff90_la_SOURCES += netcdf.f90
libnetcdff90_la_DEPENDENCIES += netcdf.f90

NETCDF_O = netcdf.o

endif # USE_NETCDF4

# Some fortran compilers think your files should not have an .f90
# extension! The value of FCFLAGS_f90 is set in the configure script,
# based on the fortran compiler.
AM_FCFLAGS += $(FCFLAGS_f90)
AM_F90FLAGS = $(FCFLAGS_f90)

# Some fortran compilers change the file names of .mod files to all
# uppercase. Just to be special.
if UPPER_CASE_MOD
nodist_include_HEADERS = TYPESIZES.mod NETCDF.mod
TYPESIZES.mod: typeSizes.o
NETCDF.mod: $(NETCDF_O)
else
nodist_include_HEADERS = typesizes.mod netcdf.mod 
typesizes.mod: typeSizes.o
netcdf.mod: $(NETCDF_O)
endif

# This is what we are building: a convenience library of F90 functions.
noinst_LTLIBRARIES = libnetcdff90.la

# Since these are included from either netcdf.f90 or netcdf4.f90, we
# have to explicitly make sure they make it into the distribution.
EXTRA_DIST += netcdf_attributes.f90 netcdf_constants.f90		\
netcdf_dims.f90 netcdf_expanded.f90 netcdf_externals.f90		\
netcdf_file.f90 netcdf_overloads.f90 netcdf_text_variables.f90		\
netcdf_variables.f90 netcdf_visibility.f90 netcdf4_func.f90		\
netcdf4_externals.f90 netcdf4_visibility.f90 netcdf4_constants.f90

CLEANFILES = typesizes.mod netcdf.mod 

