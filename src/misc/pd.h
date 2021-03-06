/* Copyright 2014. The Regents of the University of California.
 * All rights reserved. Use of this source code is governed by 
 * a BSD-style license which can be found in the LICENSE file.
 */

extern int poissondisc(int D, int N, int II, float vardens, float delta, float points[N][D]);
extern int poissondisc_mc(int D, int T, int N, int II, float vardens, const float delta[T][T], float points[N][D], int kind[N]);

extern void mc_poisson_rmatrix(int D, int T, float rmatrix[T][T], const float delta[T]);

