/* Copyright 2014. The Regents of the University of California.
 * All rights reserved. Use of this source code is governed by 
 * a BSD-style license which can be found in the LICENSE file.
 *
 * 2012-2013 Martin Uecker <uecker@eecs.berkeley.edu>
 *
 * Simple numerical phantom which simulates image-domain or
 * k-space data with multiple channels.
 *
 */

#include <math.h>
#include <complex.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>

#include "num/multind.h"
#include "num/loop.h"

#include "misc/misc.h"
#include "misc/mri.h"

#include "simu/shepplogan.h"
#include "simu/sens.h"

#include "phantom.h"




#define MAX_COILS 8
#define COIL_COEFF 5

typedef complex float (*krn_t)(void* _data, const double mpos[2]);

static complex float xsens(unsigned int c, double mpos[2], void* data, krn_t fun)
{
	assert(c < MAX_COILS);

	complex float val = 0.;

	long sh = (COIL_COEFF - 1) / 2;

	for (int i = 0; i < COIL_COEFF; i++)
		for (int j = 0; j < COIL_COEFF; j++)
			val += sens_coeff[c][i][j] * cexpf(2.i * M_PI * ((i - sh) * mpos[0] + (j - sh) * mpos[1]) / 4.);

	return val * fun(data, mpos);
}

/*
 * To simulate channels, we simply convovle with a few Fourier coefficients
 * for sensitivities. See:
 *
 * M Guerquin-Kern, L Lejeune, KP Pruessmann, and M Unser, 
 * Realistic Analytical Phantoms for Parallel Magnetic Resonance Imaging
 * IEEE TMI 31:626-636 (2012)
 */
static complex float ksens(unsigned int c, double mpos[2], void* data, krn_t fun)
{
	assert(c < MAX_COILS);

	complex float val = 0.;

	for (int i = 0; i < COIL_COEFF; i++) {
		for (int j = 0; j < COIL_COEFF; j++) {

			long sh = (COIL_COEFF - 1) / 2;

			double mpos2[2] = { mpos[0] + (double)(i - sh) / 4.,
					    mpos[1] + (double)(j - sh) / 4. };

			val += sens_coeff[c][i][j] * fun(data, mpos2);
		}
	}

	return val;
}

static complex float nosens(unsigned int c, double mpos[2], void* data, krn_t fun)
{
	UNUSED(c);
	return fun(data, mpos);
}

struct data1 {

	bool sens;
	const long dims[3];
	void* data;
	krn_t fun;
};

static complex float xkernel(void* _data, const long pos[])
{
	struct data1* data = _data;

	double mpos[2] = { (double)(2 * pos[1] - data->dims[1]) / (1. * (double)data->dims[1]),
                           (double)(2 * pos[2] - data->dims[2]) / (1. * (double)data->dims[2]) };

	return (data->sens ? xsens : nosens)(pos[COIL_DIM], mpos, data->data, data->fun);
}

static complex float kkernel(void* _data, const long pos[])
{
	struct data1* data = _data;

	double mpos[2] = { (double)(2 * pos[1] - data->dims[1]) / 4., 
			   (double)(2 * pos[2] - data->dims[2]) / 4. };

	return (data->sens ? ksens : nosens)(pos[COIL_DIM], mpos, data->data, data->fun);
}

struct data2 {

	const complex float* traj;
	long istrs[DIMS];
	bool sens;
	void* data;
	krn_t fun;
};

static complex float nkernel(void* _data, const long pos[])
{
	struct data2* data = _data;
	double mpos[3];
	mpos[0] = data->traj[md_calc_offset(3, data->istrs, pos) + 0] / 2.;
	mpos[1] = data->traj[md_calc_offset(3, data->istrs, pos) + 1] / 2.;
//	mpos[2] = data->traj[md_calc_offset(3, data->istrs, pos) + 2];

	return (data->sens ? ksens : nosens)(pos[COIL_DIM], mpos, data->data, data->fun);
}

struct krn_data {

	bool kspace;
	unsigned int N;
	const struct ellipsis_s* el;
};

static complex float krn(void* _data, const double mpos[2])
{
	struct krn_data* data = _data;
	return phantom(data->N, data->el, mpos, data->kspace);
}

static void sample(unsigned int N, const long dims[N], complex float* out, unsigned int D, const struct ellipsis_s* el, bool kspace)
{
	struct data1 data = {
		.sens = (dims[COIL_DIM] > 1),
		.dims = { dims[0], dims[1], dims[2] },
		.data = &(struct krn_data){ kspace, D, el },
		.fun = krn,
	};

	md_zsample(N, dims, out, &data, kspace ? kkernel : xkernel);
}


void calc_phantom(const long dims[DIMS], complex float* out, bool kspace)
{
	sample(DIMS, dims, out, 10, shepplogan_mod, kspace);
}





static void sample_noncart(const long dims[DIMS], complex float* out, const complex float* traj, unsigned int D, const struct ellipsis_s* el)
{
	struct data2 data = {
		.traj = traj,
		.sens = (dims[COIL_DIM] > 1),
		.data = &(struct krn_data){ true, D, el },
		.fun = krn,
	};

	assert(3 == dims[0]);

	long odims[DIMS];
	md_select_dims(DIMS, 2 + 4 + 8, odims, dims);

	long sdims[DIMS];
	md_select_dims(DIMS, 1 + 2, sdims, dims);
	md_calc_strides(DIMS, data.istrs, sdims, 1);

	md_zsample(DIMS, odims, out, &data, nkernel);
}


void calc_phantom_noncart(const long dims[DIMS], complex float* out, const complex float* traj)
{
	sample_noncart(dims, out, traj, 10, shepplogan_mod);
}


static complex float cnst_one(void* _data, const double mpos[2])
{
	UNUSED(_data);
	UNUSED(mpos);
	return 1.;
}

void calc_sens(const long dims[DIMS], complex float* sens)
{
	struct data1 data = {
		.sens = true,
		.dims = { dims[0], dims[1], dims[2] },
		.data = NULL,
		.fun = cnst_one,
	};

	md_zsample(DIMS, dims, sens, &data, xkernel);
}




void calc_circ(const long dims[DIMS], complex float* out, bool kspace)
{
	sample(DIMS, dims, out, 1, phantom_disc, kspace);
}

void calc_ring(const long dims[DIMS], complex float* out, bool kspace)
{
	sample(DIMS, dims, out, 4, phantom_ring, kspace);
}


