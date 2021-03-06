/*
   This code is part of faster_lmm_d and published under the GPLv3
   License (see LICENSE.txt)

   Copyright © 2017-2018 Prasun Anand & Pjotr Prins
*/

module faster_lmm_d.mvlmm;

import core.stdc.stdlib : exit;

import std.bitmanip;
import std.conv;
import std.exception;
import std.file;
import std.math;
import std.parallelism;
alias mlog = std.math.log;
import std.process;
import std.range;
import std.stdio;
import std.typecons;
import std.experimental.logger;
import std.string;

import faster_lmm_d.dmatrix;
import faster_lmm_d.gemma;
import faster_lmm_d.gemma_io;
import faster_lmm_d.gemma_kinship;
import faster_lmm_d.gemma_lmm;
import faster_lmm_d.gemma_param;
import faster_lmm_d.helpers;
import faster_lmm_d.kinship;
import faster_lmm_d.optmatrix;

import gsl.permutation;
import gsl.cdf;

// Results for mvLMM.
struct MPHSUMSTAT {
  double[] v_beta;  // REML estimator for beta.
  double p_wald;          // p value from a Wald test.
  double p_lrt;           // p value from a likelihood ratio test.
  double p_score;         // p value from a score test.
  double[] v_Vg;    // Estimator for Vg, right half.
  double[] v_Ve;    // Estimator for Ve, right half.
  double[] v_Vbeta; // Estimator for Vbeta, right half.
};

void mvlmm_run(string option_kinship, string option_pheno, string option_covar, string option_geno, string option_bfile){
  writeln("In MVLMM!");

  // Read Files.
  writeln("reading pheno " , option_pheno);
  auto pheno = ReadFile_pheno(option_pheno, [1,2,3,15]);
  //writeln(Y.pheno);


  int[] indicator_cvt;
  size_t n_cvt;
  writeln("reading covar " , option_covar);
  double[][] cvt = readfile_cvt(option_covar, indicator_cvt, n_cvt);
  writeln(cvt);


  writeln("reading kinship " , option_kinship);
  DMatrix G = read_covariate_matrix_from_file(option_kinship);

  CenterMatrix(G);
  auto k = kvakve(G);
  DMatrix eval = k.kva;
  DMatrix U = k.kve;

  writeln(eval.shape);
  writeln(U.shape);

  auto indicators = process_cvt_phen(pheno.indicator_pheno, cvt, indicator_cvt, n_cvt);

  //writeln(indicators.cvt);

  size_t ni_test = indicators.ni_test;
  writeln(ni_test);

  SNPINFO[] snpInfo = readfile_bim(option_bfile);

  //DMatrix W = CopyCvt(indicators.cvt, indicators.indicator_cvt, indicators.indicator_idv, indicators.n_cvt, ni_test);

  size_t ni_total = indicators.indicator_idv.length;

  string[] setSnps;

  double maf_level = 0.1;
  double  miss_level = 0.05;
  double hwe_level = 0;
  double r2_level = 0.9999;
  size_t ns_test;

  writeln(snpInfo.length);

  size_t n_ph = 4;

  DMatrix Y = zeros_dmatrix(ni_test, n_ph);
  DMatrix W = zeros_dmatrix(ni_test, n_cvt);
  CopyCvtPhen2(W, Y, indicators.indicator_idv, indicators.indicator_cvt, cvt, pheno.pheno, n_ph, n_cvt, 0);

  auto geno_result = readfile_bed(option_bfile ~ ".bed", setSnps, W, indicators.indicator_idv, snpInfo, maf_level, miss_level, hwe_level, r2_level, ns_test);
  writeln("calculated snpInfo");
  snpInfo = geno_result.snpInfo;

  DMatrix UtW = matrix_mult(U.T, W);

//  UtW.elements = [
//  1.04774, -20.664,
//0.0484649, -9.12638e-15,
//0.000416581, -3.28071e-14,
//0.0632165, 3.54161e-14,
//0.0518891, -2.13163e-14,
//0.0284744, 1.28161e-14,
//0.0259649, -3.30899e-16,
//-0.0806479, -2.90566e-15,
//-0.0365475, -6.99441e-15,
//0.299621, 2.77556e-16,
//-0.240656, 2.22045e-16,
//0.112296, 1.11022e-15,
//-0.0641494, -5.55112e-16,
//0.326486, 1.11022e-15,
//0.0792563, -5.27356e-16,
//0.0950814, 7.77156e-16,
//-0.101928, 5.55112e-16,
//0.185379, -6.80012e-16,
//-0.0293892, -1.22125e-15,
//0.089813, 5.55112e-17,
//0.0179631, 1.11022e-16,
//0.12536, -6.66134e-16,
//0.246037, 0,
//0.0418324, 3.88578e-16,
//0.226313, -1.66533e-16,
//0.126306, 6.66134e-16,
//-0.110944, 3.747e-16,
//0.0655991, -1.66533e-16,
//0.015244, -1.11022e-15,
//-0.21912, 1.48492e-15,
//-0.351667, 8.32667e-16,
//0.184053, -3.33067e-16,
//0.036866, 8.39606e-16,
//0.123818, 1.22125e-15,
//-0.0278326, -1.55431e-15,
//-0.158252, -4.61436e-16,
//0.240571, -1.33227e-15,
//0.106897, -7.77156e-16,
//-0.323911, -1.52656e-16,
//0.166513, 1.27676e-15,
//-0.0645395, 1.38778e-15,
//-0.0329447, 1.66533e-15,
//0.333249, -6.66134e-16,
//0.0136169, 1.02002e-15,
//-0.158758, -5.55112e-17,
//-0.132704, -2.77556e-16,
//0.155516, 1.16573e-15,
//-0.179699, -7.21645e-16,
//-0.0996718, -5.41234e-16,
//0.00864684, -1.88738e-15,
//-0.102787, 1.65493e-15,
//-0.0278947, -2.66454e-15,
//0.0872279, -2.88658e-15,
//0.120509, 1.55431e-15,
//-0.14885, 1.16573e-15,
//-0.0345484, -1.44329e-15,
//0.0651029, -2.02529e-16,
//0.155724, 0,
//-0.102426, -8.88178e-16,
//-0.228685, -5.55112e-16,
//-0.299936, -6.10623e-16,
//-0.0321514, 4.16334e-17,
//0.165453, -2.16493e-15,
//-0.159911, -7.21645e-16,
//-0.0226274, -1.33227e-15,
//0.0562987, 5.55112e-17,
//-0.0852282, 9.15934e-16,
//0.277015, 1.33227e-15,
//0.00831572, -3.33067e-16,
//0.164991, 7.49401e-16,
//-0.00834529, 1.14492e-16,
//0.0337915, -1.11022e-16,
//0.0901898, 2.22045e-16,
//-0.133731, 8.88178e-16,
//-0.116806, -1.11022e-16,
//-0.0720402, -1.11022e-16,
//0.0116207, -4.44089e-16,
//-0.185795, -1.01308e-15,
//0.225521, 6.66134e-16,
//-0.0943547, -6.10623e-16,
//0.0366363, -1.97065e-15,
//0.0125015, 1.22125e-15,
//0.16197, 7.21645e-16,
//0.325751, -1.11022e-15,
//0.348188, -2.22045e-16,
//-0.0753012, 6.93889e-17,
//-0.148793, -6.66134e-16,
//-0.279753, 7.77156e-16,
//-0.431571, 5.55112e-16,
//0.0811125, -1.16573e-15,
//-0.114862, 1.13798e-15,
//0.100284, -2.77556e-17,
//-0.206442, 7.21645e-16,
//0.262677, -2.77556e-16,
//-0.282948, 5.75928e-16,
//-0.141572, -1.9984e-15,
//0.108607, -1.66533e-16,
//0.0392561, 9.99201e-16,
//-0.0583558, 5.55112e-17,
//-0.204049, 2.77556e-16,
//0.0693018, -2.27596e-15,
//-0.211993, -7.21645e-16,
//-0.0217715, -1.85962e-15,
//-0.00103216, 1.55431e-15,
//-0.110504, -1.09635e-15,
//-0.137026, -1.60982e-15,
//0.219077, 3.22659e-16,
//-0.0823219, 4.44089e-16,
//-0.0873333, 1.4988e-15,
//0.256955, -6.07153e-16,
//0.147301, 3.33067e-16,
//0.298501, 8.88178e-16,
//-0.135762, -1.22125e-15,
//-0.0317334, -9.54098e-16,
//0.166275, 3.33067e-16,
//-0.130798, -1.11022e-15,
//-0.0679581, -6.10623e-16,
//0.165556, 2.22045e-16,
//-0.0577819, 1.83187e-15,
//0.113983, -4.92661e-16,
//0.0994765, 2.22045e-16,
//-0.0281641, 1.97932e-15,
//-0.11275, -1.26288e-15,
//0.0683234, -4.44089e-16,
//0.064661, -2.22045e-16,
//-0.25972, -2.22045e-16,
//-0.210536, 6.10623e-16,
//-0.273007, 2.27596e-15,
//0.387666, -1.55431e-15,
//0.149211, 8.88178e-16,
//-0.0242697, -2.35922e-15,
//-0.00962636, 1.38778e-17,
//0.0134239, 4.44089e-16,
//-0.0650054, 1.88738e-15,
//0.036256, 2.10942e-15,
//-0.0400073, 6.10623e-16,
//-0.0158883, -5.55112e-17,
//0.0201622, 5.55112e-16,
//0.0778596, 1.11022e-16,
//-0.0297186, -2.38698e-15,
//0.0479823, -1.16573e-15,
//0.196173, 1.7486e-15,
//-0.181867, 5.55112e-17,
//0.202616, -5.55112e-16,
//-0.0332085, -3.88578e-16,
//0.0932427, 3.33067e-16,
//-0.0966775, -3.33067e-16,
//-0.0408566, -4.16334e-16,
//-0.0936351, 6.48787e-16,
//-0.089639, 1.59595e-15,
//-0.231495, -1.55431e-15,
//0.35408, 1.13798e-15,
//-0.00921503, 8.32667e-17,
//0.0515647, 9.99201e-16,
//0.0986202, 1.11022e-15,
//0.0574556, -9.4369e-16,
//0.0156949, 1.11022e-16,
//-0.280903, -2.02616e-15,
//-0.0415164, -6.10623e-16,
//-0.140003, -3.88578e-16,
//0.0193923, 1.66533e-16,
//-0.0511323, 8.32667e-17,
//0.1458, -1.66533e-15,
//-0.0529923, 1.96718e-15,
//0.110273, 8.32667e-17,
//-0.0105361, -3.19189e-16,
//-0.0309588, 1.9984e-15,
//0.060729, -1.41553e-15,
//0.126946, -8.32667e-16,
//0.091658, 1.22125e-15,
//0.0509203, -1.44329e-15,
//-0.186698, -9.4369e-16,
//0.0450912, 4.44089e-16,
//0.0473551, 1.11022e-16,
//-0.0248329, 7.21645e-16,
//0.150307, 1.77636e-15,
//0.0904929, 1.66533e-16,
//-0.0817799, -3.33067e-16,
//0.114968, 2.35922e-16,
//-0.022486, 6.66134e-16,
//0.0521187, -9.99201e-16,
//0.00250525, -8.60423e-16,
//-0.229414, 2.44249e-15,
//0.00606764, 7.91034e-16,
//0.305888, -1.22125e-15,
//-0.0802275, -5.55112e-17,
//-0.270664, -3.33067e-16,
//-0.117097, -5.82867e-16,
//0.0251498, -1.11022e-16,
//-0.0123616, -1.58207e-15,
//-0.193647, 9.99201e-16,
//-0.0439658, 8.88178e-16,
//-0.0126018, 6.10623e-16,
//-0.0533495, 1.11022e-15,
//0.127873, 4.996e-16,
//0.126205, -2.77556e-16,
//-0.0435459, -1.94289e-15,
//0.167305, -5.55112e-16,
//-0.0655107, 1.72085e-15,
//-0.118092, -1.55431e-15,
//-0.12086, -1.88044e-15,
//-0.0769805, 2.22045e-15,
//0.00706194, -3.94129e-15,
//0.0635352, -4.44089e-16,
//-0.0402513, 5.55112e-16,
//0.0384016, -2.55351e-15,
//0.072119, -1.26288e-15,
//0.216832, 3.33067e-16,
//0.0280736, -2.22045e-16,
//0.00571471, 0,
//0.0260099, 2.77556e-17,
//-0.145721, 1.16573e-15,
//-0.0311977, -8.32667e-17,
//0.23217, 6.66134e-16,
//-0.100152, -2.77556e-17,
//0.401573, -2.22045e-16,
//-0.077826, 8.04912e-16,
//-0.1813, -7.21645e-16,
//0.127967, -7.77156e-16,
//-0.117759, -8.32667e-16,
//-0.0393899, 1.32533e-15,
//0.463826, -2.38698e-15,
//0.0370782, -8.88178e-16,
//0.0851465, 1.11022e-16,
//-0.116423, 8.32667e-17,
//0.208108, -1.11022e-16,
//0.0044507, 1.27676e-15,
//-0.435159, -1.33227e-15,
//-0.0683873, -5.55112e-16,
//0.0143964, -9.15934e-16,
//0.144795, -5.55112e-16,
//0.477931, -7.21645e-16,
//0.0783359, -4.44089e-16,
//0.182963, 1.94289e-16,
//-0.138703, 1.29063e-15,
//-0.36371, 1.16573e-15,
//-0.155345, 1.66533e-16,
//-0.193398, -4.44089e-16,
//-0.103289, -1.88738e-15,
//0.045557, -1.249e-16,
//-0.264733, 2.22045e-16,
//0.107154, 4.44089e-16,
//0.121808, 1.3288e-15,
//0.252351, 2.22045e-16,
//-0.0842843, -1.26288e-15,
//0.34618, -1.55431e-15,
//-0.0476203, 1.11022e-16,
//0.101377, -1.66533e-16,
//-0.274125, -8.88178e-16,
//0.024616, 1.69309e-15,
//0.0638604, 5.55112e-16,
//0.324758, -1.11022e-16,
//0.105861, 4.44089e-16,
//-0.0107999, 2.74086e-16,
//0.231998, 2.08167e-17,
//-0.0285866, 1.72085e-15,
//-0.0600147, 1.11022e-16,
//0.159975, -1.27676e-15,
//0.00418818, -6.93889e-16,
//0.00932016, 4.09395e-16,
//-0.055018, 5.96745e-16,
//0.123716, -2.22045e-16,
//0.314923, -1.55431e-15,
//0.0810768, 5.55112e-17,
//-0.0904006, 0,
//0.217486, -1.72085e-15,
//-0.298916, 3.05311e-16,
//-0.0491712, -2.72005e-15,
//-0.0744612, 1.66533e-16,
//0.0523653, -2.77556e-16,
//-0.0544762, 1.26288e-15,
//-0.0499812, -2.55351e-15,
//0.087009, 4.44089e-16,
//0.0479766, 7.21645e-16,
//0.0476955, 5.89806e-17,
//-0.0897838, -2.91434e-16,
//0.157289, 4.44089e-16,
//-0.352059, -3.33067e-16,
//-0.0144888, -1.22125e-15,
//0.0350757, -1.30451e-15,
//0.13382, -2.08167e-16,
//0.0665462, 1.80411e-16,
//-0.0162287, -1.66533e-16,
//0.00886399, 1.33227e-15,
//0.0466001, -2.63678e-16,
//-0.142406, 1.11022e-16,
//0.175957, 3.10862e-15,
//0.127664, -2.77556e-17,
//-0.0604863, 3.33067e-16,
//0.00228801, 8.88178e-16,
//0.541258, 1.44329e-15,
//0.0426972, -1.55431e-15,
//-0.33589, -2.44249e-15,
//0.107239, 9.99201e-16,
//0.0462346, 2.33147e-15,
//-0.117672, 1.66533e-16,
//0.0293998, -1.60982e-15,
//0.0693141, -1.11022e-15,
//0.155935, -3.33067e-16,
//0.153233, -1.11022e-15,
//0.0460182, 6.10623e-16,
//0.0426724, -3.88578e-15,
//-0.200843, -1.44329e-15,
//0.209166, 3.88578e-16,
//-0.234229, 1.66533e-16,
//-0.0634759, 2.22045e-16,
//-0.0743495, 7.77156e-16,
//0.365579, 0,
//-0.11922, -1.9984e-15,
//-0.272081, -4.996e-16,
//0.0472867, -1.22125e-15,
//-0.0279261, 5.55112e-16,
//-0.0554721, -6.66134e-16,
//-0.101508, -1.11022e-16,
//0.00892213, 1.55431e-15,
//-0.002375, 1.22125e-15,
//0.124599, 7.77156e-16,
//-0.300801, -1.66533e-16,
//0.0785298, 3.33067e-16,
//-0.0441663, -6.66134e-16,
//-0.0719116, -7.77156e-16,
//0.120047, 7.21645e-16,
//-0.218038, 1.66533e-16,
//-0.242717, 2.08167e-17,
//-0.236601, 6.66134e-16,
//0.145305, 9.99201e-16,
//-0.0313118, -2.22045e-16,
//-0.157147, 2.22045e-16,
//0.0212747, 1.66533e-16,
//0.172, 4.44089e-16,
//-0.10444, 5.55112e-16,
//-0.0104005, -9.99201e-16,
//0.0106382, -6.66134e-16,
//-0.371425, 1.22125e-15,
//-0.0716312, 8.60423e-16,
//0.0884496, 4.44089e-16,
//0.0295806, -1.66533e-16,
//0.0594865, 2.77556e-16,
//0.0521836, 9.99201e-16,
//0.167825, -1.48492e-15,
//0.0418652, 1.11022e-15,
//0.131241, -5.55112e-16,
//-0.012387, -7.07767e-16,
//-0.355553, -9.71445e-17,
//0.226288, -7.21645e-16,
//-0.240583, 2.22045e-16,
//0.260372, -4.996e-16,
//-0.0459446, -5.23886e-16,
//-0.101326, 8.60423e-16,
//-0.0900788, 5.55112e-16,
//-0.118763, -1.05471e-15,
//0.0459559, -4.44089e-16,
//-0.026792, -1.77636e-15,
//-0.113239, -1.55431e-15,
//-0.133611, -4.44089e-16,
//-0.222749, 5.55112e-17,
//0.171963, 7.21645e-16,
//-0.138987, -1.80411e-15,
//-0.28028, -9.99201e-16,
//-0.130867, 6.66134e-16,
//0.0723886, -1.09635e-15,
//0.0826658, -9.99201e-16,
//0.0238484, 4.92661e-16,
//-0.456946, -1.38778e-16,
//0.097588, -4.44089e-16,
//-0.0314265, 0,
//0.0248304, -4.02456e-16,
//-0.0207266, 1.63411e-15,
//-5.81854e-05, 1.38778e-15,
//-0.0810348, -2.22045e-16,
//-0.160654, -9.4369e-16,
//0.0479146, -1.41553e-15,
//0.046027, 8.60423e-16,
//0.0938735, -2.22045e-16,
//-0.257437, -1.77636e-15,
//-0.021346, -1.33227e-15,
//-0.121037, -1.4988e-15,
//-0.0710651, -1.05471e-15,
//0.0618733, -1.80411e-16,
//0.224585, -7.77156e-16,
//-0.102347, 1.22125e-15,
//0.271575, 2.67147e-16,
//-0.0471962, 3.67761e-16,
//0.0926506, 1.66533e-16,
//0.0799867, 1.4988e-15,
//-0.224081, -5.55112e-16,
//0.229322, 7.77156e-16,
//-0.102526, -1.60982e-15,
//-0.125664, 5.55112e-16,
//0.0271653, 6.66134e-16,
//0.0314906, 2.35922e-16,
//-0.196126, 5.82867e-16,
//0.139307, 1.33227e-15,
//-0.092007, -8.88178e-16,
//-0.126495, -1.11022e-15,
//0.307405, 3.33067e-16,
//0.0720744, 1.83187e-15,
//-0.148167, 2.33147e-15,
//0.282122, 6.9042e-16,
//-0.231652, 5.55112e-16,
//-0.14929, -1.11022e-15,
//0.284642, 1.38778e-15,
//0.135768, -4.996e-16,
//0.112836, 8.88178e-16,
//-0.0327966, 5.55112e-16,
//-0.144039, -5.68989e-16,
//0.0146863, -6.66134e-16,
//-0.151078, 1.44329e-15,
//-0.0981422, 1.66533e-16,
//0.224834, 1.11022e-16,
//-0.108479, -1.4988e-15,
//0.0700205, 8.88178e-16,
//0.052537, -1.11022e-16,
//-0.0381066, -5.55112e-16,
//-0.0660803, 3.33067e-16,
//-0.10455, -9.02056e-17,
//0.368227, 1.38778e-15,
//-0.00434833, -7.77156e-16,
//-0.10541, -2.88658e-15,
//0.299535, 4.44089e-16,
//-0.0355702, 2.22045e-16,
//-0.0623692, -1.44329e-15,
//-0.333344, -1.11022e-16,
//-0.0342057, 1.66533e-16,
//-0.0552144, 1.60982e-15,
//0.240776, 3.77476e-15,
//-0.188788, 4.21885e-15
//  ];
  writeln("UtW.shape =>", UtW.shape);

  DMatrix Uty = matrix_mult(U.T, Y);
  writeln("UtY.shape =>", Uty.shape);
  Param cPar;
  double trace_G = sum(eval.elements)/eval.elements.length;
  writeln("trace_G =>", trace_G);
  cPar.a_mode = 1;

  analyze_plink(U, eval, UtW, Uty, option_bfile, snpInfo, geno_result.indicator_snp, indicators.indicator_idv, ni_test);
}

void analyze_bimbam_mvlmm(const DMatrix U, const DMatrix eval,
                          const DMatrix UtW, const DMatrix UtY, string file_geno) {

  MPHSUMSTAT[] sumStat;
  string filename = file_geno;
  auto pipe = pipeShell("gunzip -c " ~ filename);
  File input = pipe.stdout;

  string ch_ptr;

  double logl_H0 = 0.0, logl_H1 = 0.0, p_wald = 0, p_lrt = 0, p_score = 0;
  double crt_a, crt_b, crt_c;
  int n_miss, c_phen;
  double geno, x_mean;
  size_t c = 0;
  size_t n_size = UtY.shape[0], d_size = UtY.shape[1], c_size = UtW.shape[1];

  size_t dc_size = d_size * (c_size + 1), v_size = d_size * (d_size + 1) / 2;

  // Create a large matrix.
  size_t LMM_BATCH_SIZE = 2000;
  size_t msize = LMM_BATCH_SIZE;
  DMatrix Xlarge   = zeros_dmatrix(U.shape[0], msize);
  DMatrix UtXlarge = zeros_dmatrix(U.shape[0], msize);

  // Large matrices for EM.
  DMatrix U_hat     = zeros_dmatrix(d_size, n_size);
  DMatrix E_hat     = zeros_dmatrix(d_size, n_size);
  DMatrix OmegaU    = zeros_dmatrix(d_size, n_size);
  DMatrix OmegaE    = zeros_dmatrix(d_size, n_size);
  DMatrix UltVehiY  = zeros_dmatrix(d_size, n_size);
  DMatrix UltVehiBX = zeros_dmatrix(d_size, n_size);
  DMatrix UltVehiU  = zeros_dmatrix(d_size, n_size);
  DMatrix UltVehiE  = zeros_dmatrix(d_size, n_size);

  // Large matrices for NR.
  // Each dxd block is H_k^{-1}.
  DMatrix Hi_all  = zeros_dmatrix(d_size, d_size * n_size);

  // Each column is H_k^{-1}y_k.
  DMatrix Hiy_all = zeros_dmatrix(d_size, n_size);

  // Each dcxdc block is x_k \otimes H_k^{-1}.
  DMatrix xHi_all = zeros_dmatrix(dc_size, d_size * n_size);
  DMatrix Hessian = zeros_dmatrix(v_size * 2, v_size * 2);

  DMatrix x      = zeros_dmatrix(1, n_size);
  DMatrix x_miss = zeros_dmatrix(1, n_size);

  DMatrix Y     = UtY.T;
  DMatrix X     = zeros_dmatrix(c_size + 1, n_size);
  DMatrix V_g   = zeros_dmatrix(d_size, d_size);
  DMatrix V_e   = zeros_dmatrix(d_size, d_size);
  DMatrix B     = zeros_dmatrix(d_size, c_size + 1);
  DMatrix beta  = zeros_dmatrix(1, d_size);
  DMatrix Vbeta = zeros_dmatrix(d_size, d_size);

  // Null estimates for initial values.
  DMatrix V_g_null  = zeros_dmatrix(d_size, d_size);
  DMatrix V_e_null  = zeros_dmatrix(d_size, d_size);
  DMatrix B_null    = zeros_dmatrix(d_size, c_size + 1);
  DMatrix se_B_null = zeros_dmatrix(d_size, c_size);

  DMatrix X_sub = UtW.T;
  X = set_sub_dmatrix(X, 0, 0, c_size, n_size, X_sub);
  DMatrix B_sub = get_sub_dmatrix(B, 0, 0, d_size, c_size);
  //gsl_matrix_view
  DMatrix xHi_all_sub = get_sub_dmatrix(xHi_all, 0, 0, d_size * c_size, d_size * n_size);
  DMatrix X_row = get_row(X, c_size);

  //gsl_vector_view
  DMatrix B_col = get_col(B, c_size);
  //gsl_vector_set_zero(B_col);

  size_t em_iter = 10; //check
  double em_prec = 0;
  size_t nr_iter = 0;
  double nr_prec = 0;
  double l_min = 1e-05;
  double l_max = 100000;
  size_t n_region = 10;

  double[] Vg_remle_null;
  double[] Ve_remle_null;
  double[] VVg_remle_null;
  double[] VVe_remle_null;
  double[] beta_remle_null;
  double[] se_beta_remle_null;
  double logl_remle_H0;

  double[] Vg_mle_null;
  double[] Ve_mle_null;
  double[] VVg_mle_null;
  double[] VVe_mle_null;
  double[] beta_mle_null;
  double[] se_beta_mle_null;
  double logl_mle_H0;
  int[] indicator_snp;
  int[] indicator_idv;
  int a_mode;
  size_t ni_test, ni_total;

  MphInitial(em_iter, em_prec, nr_iter, nr_prec, eval, X_sub, Y, l_min, l_max, n_region, V_g, V_e, B_sub);
  logl_H0 = MphEM('R', em_iter, em_prec, eval, X_sub, Y, U_hat, E_hat, OmegaU,
                    OmegaE, UltVehiY, UltVehiBX, UltVehiU, UltVehiE, V_g, V_e, B_sub);
  logl_H0 = MphNR('R', nr_iter, nr_prec, eval, X_sub, Y, Hi_all, xHi_all_sub, Hiy_all, V_g, V_e, Hessian, crt_a, crt_b, crt_c);
  MphCalcBeta(eval, X_sub, Y, V_g, V_e, UltVehiY, B_sub, se_B_null);

  c = 0;
  Vg_remle_null = [];
  Ve_remle_null = [];
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = i; j < d_size; j++) {
      Vg_remle_null ~= V_g.accessor(i, j);
      Ve_remle_null ~= V_e.accessor(i, j);
      //cpar params
      VVg_remle_null ~= Hessian.accessor(c, c);
      VVe_remle_null ~= Hessian.accessor(c + v_size, c + v_size);
      c++;
    }
  }
  beta_remle_null = [];
  se_beta_remle_null = [];
  for (size_t i = 0; i < se_B_null.shape[0]; i++) {
    for (size_t j = 0; j < se_B_null.shape[1]; j++) {
      beta_remle_null ~= B.accessor(i, j);
      se_beta_remle_null ~= se_B_null.accessor(i, j);
    }
  }
  logl_remle_H0 = logl_H0;

  writeln("REMLE estimate for Vg in the null model: ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      write(V_g.accessor(i, j), "\t");
    }
    write("\n");
  }

  writeln("se(Vg): ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      c = GetIndex(i, j, d_size);
      write(Hessian.accessor(c, c), "\t");
    }
    write("\n");
  }
  writeln("REMLE estimate for Ve in the null model: ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      write(V_e.accessor(i, j), "\t");
    }
    write("\n");
  }
  writeln("se(Ve): ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      c = GetIndex(i, j, d_size);
      write(sqrt(Hessian.accessor(c + v_size, c + v_size)), "\t");
    }
    write("\n");
  }
  writeln("REMLE likelihood = ", logl_H0);

  logl_H0 = MphEM('L', em_iter, em_prec, eval, X_sub, Y, U_hat, E_hat,
                  OmegaU, OmegaE, UltVehiY, UltVehiBX, UltVehiU, UltVehiE, V_g,
                  V_e, B_sub);
  logl_H0 = MphNR('L', nr_iter, nr_prec, eval, X_sub, Y, Hi_all,
                  xHi_all_sub, Hiy_all, V_g, V_e, Hessian, crt_a, crt_b,
                  crt_c);
  MphCalcBeta(eval, X_sub, Y, V_g, V_e, UltVehiY, B_sub, se_B_null);

  c = 0;
  Vg_mle_null = [];
  Ve_mle_null = [];
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = i; j < d_size; j++) {
      Vg_mle_null ~= V_g.accessor(i, j);
      Ve_mle_null ~= V_e.accessor(i, j);
      VVg_mle_null ~= Hessian.accessor(c, c);
      VVe_mle_null ~= Hessian.accessor(c + v_size, c + v_size);
      c++;
    }
  }
  beta_mle_null = [];
  se_beta_mle_null = [];
  for (size_t i = 0; i < se_B_null.shape[0]; i++) {
    for (size_t j = 0; j < se_B_null.shape[1]; j++) {
      beta_mle_null ~= B.accessor(i, j);
      se_beta_mle_null ~= se_B_null.accessor(i, j);
    }
  }
  logl_mle_H0 = logl_H0;

  writeln("MLE estimate for Vg in the null model: ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      write(V_g.accessor(i, j), "\t");
    }
    write("\n");
  }
  writeln("se(Vg): ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      c = GetIndex(i, j, d_size);
      write(sqrt(Hessian.accessor(c, c)), "\t");
    }
    write("\n");
  }
  writeln("MLE estimate for Ve in the null model: ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      write(V_e.accessor(i, j), "\t");
    }
    write("\n");
  }
  writeln("se(Ve): ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      c = GetIndex(i, j, d_size);
      write(sqrt(Hessian.accessor(c + v_size, c + v_size)), "\t");
    }
    write("\n");
  }
  writeln("MLE likelihood = ", logl_H0);
  double[] v_beta, v_Vg, v_Ve, v_Vbeta;
  for (size_t i = 0; i < d_size; i++) {
    v_beta ~= 0;
  }
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = i; j < d_size; j++) {
      v_Vg ~= 0;
      v_Ve ~= 0;
      v_Vbeta ~= 0;
    }
  }

  V_g_null = V_g;
  V_e_null = V_e;
  B_null = B;

  // Start reading genotypes and analyze.
  size_t csnp = 0, t_last = 0;
  for (size_t t = 0; t < indicator_snp.length; ++t) {
    if (indicator_snp[t] == 0) {
      continue;
    }
    t_last++;
  }
  int t = 0;
  foreach (line ; input.byLine) {

    if (indicator_snp[t] == 0) {
      t++;
      continue;
    }

    x_mean = 0.0;
    c_phen = 0;
    n_miss = 0;
    //gsl_vector_set_zero(x_miss);
    auto chr = to!string(line).split(",")[3..$];
    for (size_t i = 0; i < ni_total; ++i) {
      ch_ptr = chr[i];
      if (indicator_idv[i] == 0) {
        continue;
      }

      if (ch_ptr == "NA") {
        x_miss.elements[c_phen] = 0.0;
        n_miss++;
      } else {
        geno = to!double(ch_ptr);

        x.elements[c_phen] = geno;
        x_miss.elements[c_phen] = 1.0;
        x_mean += geno;
      }
      c_phen++;
    }

    x_mean /= to!double(ni_test - n_miss);

    for (size_t i = 0; i < ni_test; ++i) {
      if (x_miss.elements[i] == 0) {
        x.elements[i] = x_mean;
      }
      geno = x.elements[i];
    }

    DMatrix Xlarge_col = get_col(Xlarge, csnp % msize);
    //gsl_vector_memcpy(Xlarge_col, x);
    csnp++;

    if (csnp % msize == 0 || csnp == t_last) {
      size_t l = 0;
      if (csnp % msize == 0) {
        l = msize;
      } else {
        l = csnp % msize;
      }

      //gsl_matrix_view
      DMatrix Xlarge_sub = get_sub_dmatrix(Xlarge, 0, 0, Xlarge.shape[0], l);
      //gsl_matrix_view
      DMatrix UtXlarge_sub = get_sub_dmatrix(UtXlarge, 0, 0, UtXlarge.shape[0], l);

      UtXlarge_sub = matrix_mult(U.T, Xlarge_sub);

      //gsl_matrix_set_zero(Xlarge);
      Xlarge = zeros_dmatrix(Xlarge.shape[0], Xlarge.shape[1]);

      for (size_t i = 0; i < l; i++) {
        //gsl_vector_view
        DMatrix UtXlarge_col = get_col(UtXlarge, i);
        //gsl_vector_memcpy(X_row, UtXlarge_col);

        // Initial values.
        V_g = V_g_null;
        V_e = V_e_null;
        B = B_null;

        // 3 is before 1.
        //set Values
        double p_nr, crt;

        if (a_mode == 3 || a_mode == 4) {
          p_score = MphCalcP(eval, X_row, X_sub, Y, V_g_null,
                             V_e_null, UltVehiY, beta, Vbeta);
          if (p_score < p_nr && crt == 1) {
            logl_H1 = MphNR('R', 1, nr_prec * 10, eval, X, Y, Hi_all, xHi_all,
                            Hiy_all, V_g, V_e, Hessian, crt_a, crt_b, crt_c);
            p_score = PCRT(3, d_size, p_score, crt_a, crt_b, crt_c);
          }
        }

        if (a_mode == 2 || a_mode == 4) {
          logl_H1 = MphEM('L', em_iter / 10, em_prec * 10, eval, X, Y, U_hat,
                          E_hat, OmegaU, OmegaE, UltVehiY, UltVehiBX, UltVehiU,
                          UltVehiE, V_g, V_e, B);

          // Calculate beta and Vbeta.
          p_lrt = MphCalcP(eval, X_row, X_sub, Y, V_g, V_e, UltVehiY, beta, Vbeta);
          p_lrt = gsl_cdf_chisq_Q(2.0 * (logl_H1 - logl_H0), to!double(d_size));

          if (p_lrt < p_nr) {
            logl_H1 =
                MphNR('L', nr_iter / 10, nr_prec * 10, eval, X, Y, Hi_all,
                      xHi_all, Hiy_all, V_g, V_e, Hessian, crt_a, crt_b, crt_c);

            // Calculate beta and Vbeta.
            p_lrt = MphCalcP(eval, X_row, X_sub, Y, V_g, V_e, UltVehiY, beta, Vbeta);
            p_lrt = gsl_cdf_chisq_Q(2.0 * (logl_H1 - logl_H0), to!double(d_size));

            if (crt == 1) {
              p_lrt = PCRT(2, d_size, p_lrt, crt_a, crt_b, crt_c);
            }
          }
        }

        if (a_mode == 1 || a_mode == 4) {
          logl_H1 = MphEM('R', em_iter / 10, em_prec * 10, eval, X, Y, U_hat,
                          E_hat, OmegaU, OmegaE, UltVehiY, UltVehiBX, UltVehiU,
                          UltVehiE, V_g, V_e, B);
          p_wald = MphCalcP(eval, X_row, X_sub, Y, V_g, V_e, UltVehiY, beta, Vbeta);

          if (p_wald < p_nr) {
            logl_H1 = MphNR('R', nr_iter / 10, nr_prec * 10, eval, X, Y, Hi_all,
                            xHi_all, Hiy_all, V_g, V_e, Hessian, crt_a, crt_b, crt_c);
            p_wald = MphCalcP(eval, X_row, X_sub, Y, V_g, V_e, UltVehiY, beta, Vbeta);

            if (crt == 1) {
              p_wald = PCRT(1, d_size, p_wald, crt_a, crt_b, crt_c);
            }
          }
        }

        // Store summary data.
        for (size_t k = 0; k < d_size; k++) {
          v_beta[k] = beta.elements[k];
        }

        c = 0;
        for (size_t k = 0; k < d_size; k++) {
          for (size_t j = k; j < d_size; j++) {
            v_Vg[c] = V_g.accessor(k, j);
            v_Ve[c] = V_e.accessor(k, j);
            v_Vbeta[c] = Vbeta.accessor(k, j);
            c++;
          }
        }

        MPHSUMSTAT SNPs = {v_beta, p_wald, p_lrt, p_score, v_Vg, v_Ve, v_Vbeta};
        sumStat ~= SNPs;
      }
    }

    t++;
  }
  return;
}

// Initialize Vg, Ve and B.
void MphInitial(const size_t em_iter, const double em_prec,
                const size_t nr_iter, const double nr_prec,
                const DMatrix eval, const DMatrix X, const DMatrix Y,
                const double l_min, const double l_max, const size_t n_region,
                ref DMatrix V_g, ref DMatrix V_e, ref DMatrix B) {

  writeln("entered MphInitial");

  V_g = zeros_dmatrix(V_g.shape[0], V_g.shape[1]);
  V_e = zeros_dmatrix(V_e.shape[0], V_e.shape[1]);
  B   = zeros_dmatrix(B.shape[0], B.shape[1]);

  size_t n_size = eval.elements.length, c_size = X.shape[0], d_size = Y.shape[0];
  double a, b, c;
  double lambda, logl, vg, ve;

  // Initialize the diagonal elements of Vg and Ve using univariate
  // LMM and REML estimates.
  DMatrix Xt = zeros_dmatrix(n_size, c_size);
  DMatrix beta_temp = zeros_dmatrix(c_size, 1);
  DMatrix se_beta_temp = zeros_dmatrix(c_size, 1);

  writeln(n_size, " ", c_size);

  Xt = X.T;

  writeln("X", X.shape);
  writeln("Y", Y.shape);

  for (size_t i = 0; i < d_size; i++) {
    DMatrix Y_row = get_row(Y, i);
    auto res = calc_lambda('R', eval, Xt, Y_row, l_min, l_max, n_region);
    lambda = res.lambda;
    writeln(lambda);
    logl = res.logf;
    writeln(logl);

    auto vgvebeta = CalcLmmVgVeBeta(eval, Xt, Y_row, lambda);

    V_g.set(i, i, vgvebeta.vg);
    V_e.set(i, i, vgvebeta.ve);
  }

  // If number of phenotypes is above four, then obtain the off
  // diagonal elements with two trait models.
  if (d_size > 4) {

    // First obtain good initial values.
    // Large matrices for EM.
    DMatrix U_hat = zeros_dmatrix(2, n_size);
    DMatrix E_hat = zeros_dmatrix(2, n_size);
    DMatrix OmegaU = zeros_dmatrix(2, n_size);
    DMatrix OmegaE = zeros_dmatrix(2, n_size);
    DMatrix UltVehiY = zeros_dmatrix(2, n_size);
    DMatrix UltVehiBX = zeros_dmatrix(2, n_size);
    DMatrix UltVehiU = zeros_dmatrix(2, n_size);
    DMatrix UltVehiE = zeros_dmatrix(2, n_size);

    // Large matrices for NR. Each dxd block is H_k^{-1}.
    DMatrix Hi_all = zeros_dmatrix(2, 2 * n_size);

    // Each column is H_k^{-1}y_k.
    DMatrix Hiy_all = zeros_dmatrix(2, n_size);

    // Each dcxdc block is x_k\otimes H_k^{-1}.
    DMatrix xHi_all = zeros_dmatrix(2 * c_size, 2 * n_size);
    DMatrix Hessian = zeros_dmatrix(6, 6);

    // 2 by n matrix of Y.
    DMatrix Y_sub = zeros_dmatrix(2, n_size);
    DMatrix Vg_sub = zeros_dmatrix(2, 2);
    DMatrix Ve_sub = zeros_dmatrix(2, 2);
    DMatrix B_sub = zeros_dmatrix(2, c_size);

    for (size_t i = 0; i < d_size; i++) {
      //gsl_vector_view
      DMatrix Y_sub1 = get_row(Y_sub, 0);
      //gsl_vector_const_view
      DMatrix Y_1 = get_row(Y, i);
      Y_sub1 = Y_1;

      writeln("d_size = ", d_size);

      for (size_t j = i + 1; j < d_size; j++) {
        //gsl_vector_view
        DMatrix Y_sub2 = get_row(Y_sub, 1);
        //gsl_vector_const_view
        DMatrix Y_2 = get_row(Y, j);
        Y_sub2 = Y_2;

        Vg_sub = zeros_dmatrix(Vg_sub.shape[0], Vg_sub.shape[1]);
        Ve_sub = zeros_dmatrix(Ve_sub.shape[0], Ve_sub.shape[1]);
        Vg_sub.set(0, 0, V_g.accessor(i, i));
        Ve_sub.set(0, 0, V_e.accessor(i, i));
        Vg_sub.set(1, 1, V_g.accessor(j, j));
        Ve_sub.set(1, 1, V_e.accessor(j, j));

        logl = MphEM('R', em_iter, em_prec, eval, X, Y_sub, U_hat, E_hat,
                     OmegaU, OmegaE, UltVehiY, UltVehiBX, UltVehiU, UltVehiE,
                     Vg_sub, Ve_sub, B_sub);
        logl = MphNR('R', nr_iter, nr_prec, eval, X, Y_sub, Hi_all, xHi_all,
                     Hiy_all, Vg_sub, Ve_sub, Hessian, a, b, c);

        V_g.set(i, j, Vg_sub.accessor(0, 1));
        V_g.set(j, i, Vg_sub.accessor(0, 1));

        V_e.set(i, j, Ve_sub.accessor(0, 1));
        V_e.set(j, i, Ve_sub.accessor(0, 1));
      }
    }
  }

  // Calculate B hat using GSL estimate.
  DMatrix UltVehiY = zeros_dmatrix(d_size, n_size);

  DMatrix D_l = zeros_dmatrix(d_size, 1);
  DMatrix UltVeh = zeros_dmatrix(d_size, d_size);
  DMatrix UltVehi = zeros_dmatrix(d_size, d_size);
  DMatrix Qi = zeros_dmatrix(d_size * c_size, d_size * c_size);
  DMatrix beta = zeros_dmatrix(d_size * c_size, 1);
  DMatrix XHiy = zeros_dmatrix(d_size * c_size, 1);

  double dl, d, delta, dx, dy;

  // Eigen decomposition and calculate log|Ve|.
  // double logdet_Ve = EigenProc(V_g, V_e, D_l, UltVeh, UltVehi);
  EigenProc(V_g, V_e, D_l, UltVeh, UltVehi);

  // Calculate Qi and log|Q|.
  // double logdet_Q = CalcQi(eval, D_l, X, Qi);
  CalcQi(eval, D_l, X, Qi);

  // Calculate UltVehiY.
  UltVehiY =  matrix_mult(UltVehi, Y);

  // calculate XHiy
  for (size_t i = 0; i < d_size; i++) {
    dl = D_l.elements[i];

    for (size_t j = 0; j < c_size; j++) {
      d = 0.0;
      for (size_t k = 0; k < n_size; k++) {
        delta = eval.elements[k];
        dx = X.accessor(j, k);
        dy = UltVehiY.accessor(i, k);
        d += dy * dx / (delta * dl + 1.0);
      }
      XHiy.elements[j * d_size + i] = d;
    }
  }

  beta = matrix_mult(Qi, XHiy);

  // Multiply beta by UltVeh and save to B.
  for (size_t i = 0; i < c_size; i++) {
    DMatrix B_col = get_col(B, i);
    //gsl_vector_view
    DMatrix beta_sub = get_subvector_dmatrix(beta, i * d_size, d_size);
    B_col = matrix_mult(UltVeh.T, beta_sub);
    B_col = matrix_mult(beta_sub, UltVeh);
    set_col2(B, i, B_col.T);
  }

  writeln("out of MphInitial");
  return;
}

size_t GetIndex(const size_t i, const size_t j, const size_t d_size) {
  if (i >= d_size || j >= d_size) {
    writeln("error in GetIndex.");
    return 0;
  }

  size_t s, l;
  if (j < i) {
    s = j;
    l = i;
  } else {
    s = i;
    l = j;
  }
  return (2 * d_size - s + 1) * s / 2 + l - s;
}

double MphEM(const char func_name, const size_t max_iter, const double max_prec,
             const DMatrix eval, const DMatrix X, const DMatrix Y,
             ref DMatrix U_hat, ref DMatrix E_hat, ref DMatrix OmegaU,
             ref DMatrix OmegaE, ref DMatrix UltVehiY, ref DMatrix UltVehiBX,
             ref DMatrix UltVehiU, ref DMatrix UltVehiE, ref DMatrix V_g,
             ref DMatrix V_e, ref DMatrix B) {
  writeln("entered MphEM");

  if (func_name != 'R' && func_name != 'L' && func_name != 'r' && func_name != 'l') {
    writeln("func_name only takes 'R' or 'L': 'R' for log-restricted likelihood, 'L' for log-likelihood.");
    return 0.0;
  }

  size_t n_size = eval.size, c_size = X.shape[0], d_size = Y.shape[0];
  size_t dc_size = d_size * c_size;

  DMatrix XXt = zeros_dmatrix(c_size, c_size);
  DMatrix XXti = zeros_dmatrix(c_size, c_size);
  DMatrix D_l = zeros_dmatrix(1, d_size);
  DMatrix UltVeh = zeros_dmatrix(d_size, d_size);
  DMatrix UltVehi = zeros_dmatrix(d_size, d_size);
  DMatrix UltVehiB = zeros_dmatrix(d_size, c_size);
  DMatrix Qi = zeros_dmatrix(dc_size, dc_size);
  DMatrix Sigma_uu = zeros_dmatrix(d_size, d_size);
  DMatrix Sigma_ee = zeros_dmatrix(d_size, d_size);
  DMatrix xHiy = zeros_dmatrix(1, dc_size);

  double logl_const = 0.0, logl_old = 0.0, logl_new = 0.0;
  double logdet_Q, logdet_Ve;

  // Calculate |XXt| and (XXt)^{-1}.
  XXt = syrk(1, X, 0, XXt);


  for (size_t i = 0; i < c_size; ++i) {
    for (size_t j = 0; j < i; ++j) {
      XXt.set(i, j, XXt.accessor(j, i));
    }
  }

  XXti = XXt.inverse;

  // Calculate the constant for logl.
  if (func_name == 'R' || func_name == 'r') {
    logl_const =
        -0.5 * to!double(n_size - c_size) * to!double(d_size) * mlog(2.0 * PI) +
        0.5 * to!double(d_size) * mlog(det(XXt));
  } else {
    logl_const = -0.5 * to!double(n_size) * to!double(d_size) * mlog(2.0 * PI);
  }
  writeln("logl_const =>", logl_const);
  //assert(abs(logl_const -(-1545.346)) < 1e-3);
  // Start EM.
  writeln("max_iter => ", max_iter);
  for (size_t t = 0; t < max_iter; t++) {
    writeln("iter => ", t);
    logdet_Ve = EigenProc(V_g, V_e, D_l, UltVeh, UltVehi);
    logdet_Q = CalcQi(eval, D_l, X, Qi);
    UltVehiY = matrix_mult(UltVehi, Y);
    CalcXHiY(eval, D_l, X, UltVehiY, xHiy);

    // Calculate log likelihood/restricted likelihood value, and
    // terminate if change is small.
    logl_new = logl_const + MphCalcLogL(eval, xHiy, D_l, UltVehiY, Qi) -
               0.5 * to!double(n_size) * logdet_Ve;
    if (func_name == 'R' || func_name == 'r') {
      logl_new += -0.5 * (logdet_Q - to!double(c_size) * logdet_Ve);
    }
    if (t != 0 && abs(logl_new - logl_old) < max_prec) {
      writeln("break");
      break;
    }
    logl_old = logl_new;

    CalcOmega(eval, D_l, OmegaU, OmegaE);

    // Update UltVehiB, UltVehiU.
    if (func_name == 'R' || func_name == 'r') {
      UpdateRL_B(xHiy, Qi, UltVehiB);
      UltVehiBX = matrix_mult(UltVehiB, X);
    } else if (t == 0) {
      UltVehiB = matrix_mult(UltVehi, B);
      UltVehiBX = matrix_mult(UltVehiB, X);
    }

    UpdateU(OmegaE, UltVehiY, UltVehiBX, UltVehiU);

    if (func_name == 'L' || func_name == 'l') {

      // UltVehiBX is destroyed here.
      UpdateL_B(X, XXti, UltVehiY, UltVehiU, UltVehiBX, UltVehiB);
      UltVehiBX = matrix_mult(UltVehiB, X);
    }

    UpdateE(UltVehiY, UltVehiBX, UltVehiU, UltVehiE);

    // Calculate U_hat, E_hat and B.
    U_hat = matrix_mult(UltVeh.T, UltVehiU);
    E_hat = matrix_mult(UltVeh.T, UltVehiE);
    B = matrix_mult(UltVeh.T, UltVehiB);

    // Calculate Sigma_uu and Sigma_ee.
    CalcSigma(func_name, eval, D_l, X, OmegaU, OmegaE, UltVeh, Qi, Sigma_uu, Sigma_ee);

    // Update V_g and V_e.
    UpdateV(eval, U_hat, E_hat, Sigma_uu, Sigma_ee, V_g, V_e);
  }
  writeln("logl_new => ", logl_new);
  return logl_new;
}

double MphNR(const char func_name, const size_t max_iter, const double max_prec,
             const DMatrix eval, const DMatrix X, const DMatrix Y,
             ref DMatrix Hi_all, ref DMatrix xHi_all, ref DMatrix Hiy_all,
             ref DMatrix V_g, ref DMatrix V_e, ref DMatrix Hessian_inv,
             ref double crt_a, ref double crt_b, ref double crt_c) {
  writeln("in MphNR");
  if (func_name != 'R' && func_name != 'L' && func_name != 'r' && func_name != 'l') {
    writeln("func_name only takes 'R' or 'L': 'R' for log-restricted likelihood, 'L' for log-likelihood.");
    return 0.0;
  }
  size_t n_size = eval.size, c_size = X.shape[0], d_size = Y.shape[0];
  size_t dc_size = d_size * c_size;
  size_t v_size = d_size * (d_size + 1) / 2;

  double logdet_H, logdet_Q, yPy, logl_const;
  double logl_old = 0.0, logl_new = 0.0, step_scale;
  int sig;
  size_t step_iter, flag_pd;

  DMatrix Vg_save = zeros_dmatrix(d_size, d_size);
  DMatrix Ve_save = zeros_dmatrix(d_size, d_size);
  DMatrix V_temp = zeros_dmatrix(d_size, d_size);
  DMatrix U_temp = zeros_dmatrix(d_size, d_size);
  DMatrix D_temp = zeros_dmatrix(d_size, 1);
  DMatrix xHiy = zeros_dmatrix(dc_size, 1);
  DMatrix QixHiy = zeros_dmatrix(dc_size, 1);
  DMatrix Qi = zeros_dmatrix(dc_size, dc_size);
  DMatrix XXt = zeros_dmatrix(c_size, c_size);

  DMatrix gradient = zeros_dmatrix(v_size * 2, 1);

  // Calculate |XXt| and (XXt)^{-1}.
  XXt = matrix_mult(X, X.T);
  //XXt = syrk(1, X, 0, XXt); // check which is faster
  for (size_t i = 0; i < c_size; ++i) {
    for (size_t j = 0; j < i; ++j) {
      XXt.set(i, j, XXt.accessor(j, i));
    }
  }

  // Calculate the constant for logl.
  if (func_name == 'R' || func_name == 'r') {
    logl_const =
        -0.5 * to!double(n_size - c_size) * to!double(d_size) * mlog(2.0 * PI) +
        0.5 * to!double(d_size) * det(XXt);
  } else {
    logl_const = -0.5 * to!double(n_size) * to!double(d_size) * mlog(2.0 * PI);
  }

  // Optimization iterations.
  for (size_t t = 0; t < max_iter; t++) {
    writeln("Optimization iterations iter =>", t);
    Vg_save = dup_dmatrix(V_g); // Check dup
    Ve_save = dup_dmatrix(V_e);

    step_scale = 1.0;
    step_iter = 0;
    do {
      V_g = cast(DMatrix)Vg_save;
      V_e = Ve_save;

      // Update Vg, Ve, and invert Hessian.
      if (t != 0) {
        UpdateVgVe(Hessian_inv, gradient, step_scale, V_g, V_e);
      }
      // Check if both Vg and Ve are positive definite.
      flag_pd = 1;
      V_temp = V_e;
      EigenDecomp(V_temp, U_temp, D_temp, 0);
      for (size_t i = 0; i < d_size; i++) {
        if (D_temp.elements[i] <= 0) {
          flag_pd = 0;
        }
      }
      V_temp = V_g;
      EigenDecomp(V_temp, U_temp, D_temp, 0);
      for (size_t i = 0; i < d_size; i++) {
        if (D_temp.elements[i] <= 0) {
          flag_pd = 0;
        }
      }
      // If flag_pd==1, continue to calculate quantities
      // and logl.
      if (flag_pd == 1) {
        CalcHiQi(eval, X, V_g, V_e, Hi_all, Qi, logdet_H, logdet_Q);
        Calc_Hiy_all(Y, Hi_all, Hiy_all);
        Calc_xHi_all(X, Hi_all, xHi_all);
        // Calculate QixHiy and yPy.
        Calc_xHiy(Y, xHi_all, xHiy);
        QixHiy = matrix_mult(Qi, xHiy);

        yPy = vector_ddot(QixHiy, xHiy);
        yPy = Calc_yHiy(Y, Hiy_all) - yPy;

        // Calculate log likelihood/restricted likelihood value.
        if (func_name == 'R' || func_name == 'r') {
          logl_new = logl_const - 0.5 * logdet_H - 0.5 * logdet_Q - 0.5 * yPy;
        } else {
          logl_new = logl_const - 0.5 * logdet_H - 0.5 * yPy;
        }
      }

      step_scale /= 2.0;
      step_iter++;

    } while (
        (flag_pd == 0 || logl_new < logl_old || logl_new - logl_old > 10) &&
        step_iter < 10 && t != 0);
    // Terminate if change is small.
    if (t != 0) {
      if (logl_new < logl_old || flag_pd == 0) {
        V_g = Vg_save;  // Check dup
        V_e = Ve_save;
        break;
      }

      if (logl_new - logl_old < max_prec) {
        break;
      }
    }

    writeln("out of opt loops");
    logl_old = logl_new;

    writeln("Hi_all.shape => ", Hi_all.shape);

    CalcDev(func_name, eval, Qi, Hi_all, xHi_all, Hiy_all, QixHiy, gradient, Hessian_inv, crt_a, crt_b, crt_c);
  }

  // Mutiply Hessian_inv with -1.0.
  // Now Hessian_inv is the variance matrix.
  Hessian_inv = multiply_dmatrix_num(Hessian_inv, -1.0);

  return logl_new;
}

// Calculate p-value, beta (d by 1 vector) and V(beta).
double MphCalcP(const DMatrix eval, const DMatrix x_vec, const DMatrix W,
                const DMatrix Y, const DMatrix V_g, const DMatrix V_e,
                ref DMatrix UltVehiY, ref DMatrix beta, ref DMatrix Vbeta) {
  writeln("in MphCalcP");
  size_t n_size = eval.elements.length, c_size = W.shape[0], d_size = V_g.shape[0];
  size_t dc_size = d_size * c_size;
  double delta, dl, d, d1, d2, dy, dx, dw; //  logdet_Ve, logdet_Q, p_value;

  DMatrix D_l = zeros_dmatrix(1, d_size);
  DMatrix UltVeh = zeros_dmatrix(d_size, d_size);
  DMatrix UltVehi = zeros_dmatrix(d_size, d_size);
  DMatrix Qi = zeros_dmatrix(dc_size, dc_size);
  DMatrix WHix = zeros_dmatrix(dc_size, d_size);
  DMatrix QiWHix = zeros_dmatrix(dc_size, d_size);

  DMatrix xPx = zeros_dmatrix(d_size, d_size);
  DMatrix xPy = zeros_dmatrix(1, d_size);
  DMatrix WHiy = zeros_dmatrix(1, dc_size);

  // Eigen decomposition and calculate log|Ve|.
  EigenProc(V_g, V_e, D_l, UltVeh, UltVehi);

  // Calculate Qi and log|Q|.
  CalcQi(eval, D_l, W, Qi);

  // Calculate UltVehiY.
  UltVehiY = matrix_mult(UltVehi, Y);

  // Calculate WHix, WHiy, xHiy, xHix.
  for (size_t i = 0; i < d_size; i++) {
    dl = D_l.elements[i];

    d1 = 0.0;
    d2 = 0.0;
    for (size_t k = 0; k < n_size; k++) {
      delta = eval.elements[k];
      dx = x_vec.elements[k];
      dy = UltVehiY.accessor(i, k);

      d1 += dx * dy / (delta * dl + 1.0);
      d2 += dx * dx / (delta * dl + 1.0);
    }
    xPy.elements[i] = d1;
    xPx.set(i, i, d2);

    for (size_t j = 0; j < c_size; j++) {
      d1 = 0.0;
      d2 = 0.0;
      for (size_t k = 0; k < n_size; k++) {
        delta = eval.elements[k];
        dx = x_vec.elements[k];
        dw = W.accessor(j, k);
        dy = UltVehiY.accessor(i, k);

        d1 += dx * dw / (delta * dl + 1.0);
        d2 += dy * dw / (delta * dl + 1.0);
      }
      WHix.set(j * d_size + i, i, d1);
      WHiy.elements[j * d_size + i] = d2;
    }
  }

  QiWHix = matrix_mult(Qi, WHix);
  xPx    = matrix_mult(WHix.T, QiWHix);
  xPy    = matrix_mult(QiWHix.T, WHiy);

  // Calculate V(beta) and beta.
  D_l = xPx.solve(xPy);
  Vbeta = xPx.inverse();

  // Need to multiply UltVehi on both sides or one side.
  beta  = matrix_mult(UltVeh.T, D_l);
  xPx   = matrix_mult(Vbeta, UltVeh);
  Vbeta = matrix_mult(UltVeh.T, xPx);

  // Calculate test statistic and p value.
  d = vector_ddot(D_l, xPy);

  double p_value = gsl_cdf_chisq_Q(d, to!double(d_size));

  return p_value;
}

void MphCalcBeta(const DMatrix eval, const DMatrix W, const DMatrix Y, const DMatrix V_g,
                 const DMatrix V_e, ref DMatrix UltVehiY, ref DMatrix B, ref DMatrix se_B) {
  writeln("in MphCalcBeta", Y.shape);
  size_t n_size = eval.size, c_size = W.shape[0], d_size = V_g.shape[0];
  size_t dc_size = d_size * c_size;
  double delta, dl, d, dy, dw; // , logdet_Ve, logdet_Q;

  writeln("d_size = ", d_size);
  writeln("V_g.shape", V_g.shape);

  DMatrix D_l = zeros_dmatrix(d_size, 1);
  DMatrix UltVeh = zeros_dmatrix(d_size, d_size);
  DMatrix UltVehi = zeros_dmatrix(d_size, d_size);
  DMatrix Qi = zeros_dmatrix(dc_size, dc_size);
  DMatrix Qi_temp = zeros_dmatrix(dc_size, dc_size);
  DMatrix WHiy = zeros_dmatrix(dc_size, 1);
  DMatrix QiWHiy = zeros_dmatrix(dc_size, 1);
  DMatrix beta = zeros_dmatrix(dc_size, 1);
  DMatrix Vbeta = zeros_dmatrix(dc_size, dc_size);

  WHiy = zeros_dmatrix(WHiy.shape[0], WHiy.shape[1]);

  // Eigen decomposition and calculate log|Ve|.
  // double logdet_Ve = EigenProc(V_g, V_e, D_l, UltVeh, UltVehi);
  EigenProc(V_g, V_e, D_l, UltVeh, UltVehi);

  // Calculate Qi and log|Q|.
  // double logdet_Q = CalcQi(eval, D_l, W, Qi);
  CalcQi(eval, D_l, W, Qi);
  // Calculate UltVehiY.
  UltVehiY = matrix_mult(UltVehi, Y);

  // Calculate WHiy.
  for (size_t i = 0; i < d_size; i++) {
    dl = D_l.elements[i];
    for (size_t j = 0; j < c_size; j++) {
      for (size_t k = 0; k < n_size; k++) {
        delta = eval.elements[k];
        dw = W.accessor(j, k);
        dy = UltVehiY.accessor(i, k);
        d += dy * dw / (delta * dl + 1.0);
      }
      WHiy.elements[j * d_size + i] = d;
    }
  }

  QiWHiy = matrix_mult(Qi, WHiy);

  // Need to multiply I_c\otimes UltVehi on both sides or one side.
  for (size_t i = 0; i < c_size; i++) {
    //gsl_vector_view
    DMatrix QiWHiy_sub = get_subvector_dmatrix(QiWHiy, i * d_size, d_size);
    //gsl_vector_view
    DMatrix beta_sub = get_subvector_dmatrix(beta, i * d_size, d_size);
    beta_sub = matrix_mult(UltVeh, QiWHiy_sub);

    for (size_t j = 0; j < c_size; j++) {
      //gsl_matrix_view
      DMatrix Qi_sub = get_sub_dmatrix(Qi, i * d_size, j * d_size, d_size, d_size);
      //gsl_matrix_view
      DMatrix Qitemp_sub = get_sub_dmatrix(Qi_temp, i * d_size, j * d_size, d_size, d_size);
      //gsl_matrix_view
      DMatrix Vbeta_sub = get_sub_dmatrix(Vbeta, i * d_size, j * d_size, d_size, d_size);

      if (j < i) {
        //gsl_matrix_view
        DMatrix Vbeta_sym = get_sub_dmatrix(Vbeta, j * d_size, i * d_size, d_size, d_size);
        Vbeta_sub = Vbeta_sym.T;
      } else {
        Qitemp_sub = matrix_mult(Qi_sub, UltVeh);
        Vbeta_sub = matrix_mult(UltVeh, Qitemp_sub);
      }
    }
  }

  // Copy beta to B, and Vbeta to se_B.
  for (size_t j = 0; j < B.shape[1]; j++) {
    for (size_t i = 0; i < B.shape[0]; i++) {
      B.set(i, j, beta.elements[j * d_size + i]);
      se_B.set(i, j, sqrt(Vbeta.accessor(j * d_size + i, j * d_size + i)));
    }
  }

  return;
}

// Calculate first-order and second-order derivatives.
void CalcDev(const char func_name, const DMatrix eval, const DMatrix Qi,
             const DMatrix Hi, const DMatrix xHi, const DMatrix Hiy,
             const DMatrix QixHiy, ref DMatrix gradient, ref DMatrix Hessian_inv,
             ref double crt_a, ref double crt_b, ref double crt_c) {

  writeln("in CalcDev");

  if (func_name != 'R' && func_name != 'L' && func_name != 'r' && func_name != 'l') {
    writeln("func_name only takes 'R' or 'L': 'R' for log-restricted likelihood, 'L' for log-likelihood.");
    return;
  }

  size_t dc_size = Qi.shape[0], d_size = Hi.shape[0];
  size_t c_size = dc_size / d_size;
  size_t v_size = d_size * (d_size + 1) / 2;
  size_t v1, v2;
  double dev1_g, dev1_e, dev2_gg, dev2_ee, dev2_ge;

  DMatrix Hessian = zeros_dmatrix(v_size * 2, v_size * 2);

  DMatrix xHiDHiy_all_g = zeros_dmatrix(dc_size, v_size);
  DMatrix xHiDHiy_all_e = zeros_dmatrix(dc_size, v_size);
  DMatrix xHiDHix_all_g = zeros_dmatrix(dc_size, v_size * dc_size);
  DMatrix xHiDHix_all_e = zeros_dmatrix(dc_size, v_size * dc_size);
  DMatrix xHiDHixQixHiy_all_g = zeros_dmatrix(dc_size, v_size);
  DMatrix xHiDHixQixHiy_all_e = zeros_dmatrix(dc_size, v_size);

  DMatrix QixHiDHiy_all_g = zeros_dmatrix(dc_size, v_size);
  DMatrix QixHiDHiy_all_e = zeros_dmatrix(dc_size, v_size);
  DMatrix QixHiDHix_all_g = zeros_dmatrix(dc_size, v_size * dc_size);
  DMatrix QixHiDHix_all_e = zeros_dmatrix(dc_size, v_size * dc_size);
  DMatrix QixHiDHixQixHiy_all_g = zeros_dmatrix(dc_size, v_size);
  DMatrix QixHiDHixQixHiy_all_e = zeros_dmatrix(dc_size, v_size);

  DMatrix xHiDHiDHiy_all_gg = zeros_dmatrix(dc_size, v_size * v_size);
  DMatrix xHiDHiDHiy_all_ee = zeros_dmatrix(dc_size, v_size * v_size);
  DMatrix xHiDHiDHiy_all_ge = zeros_dmatrix(dc_size, v_size * v_size);
  DMatrix xHiDHiDHix_all_gg = zeros_dmatrix(dc_size, v_size * v_size * dc_size);
  DMatrix xHiDHiDHix_all_ee = zeros_dmatrix(dc_size, v_size * v_size * dc_size);
  DMatrix xHiDHiDHix_all_ge = zeros_dmatrix(dc_size, v_size * v_size * dc_size);

  // Calculate xHiDHiy_all, xHiDHix_all and xHiDHixQixHiy_all.
  Calc_xHiDHiy_all(eval, xHi, Hiy, xHiDHiy_all_g, xHiDHiy_all_e);

  Calc_xHiDHix_all(eval, xHi, xHiDHix_all_g, xHiDHix_all_e);
  Calc_xHiDHixQixHiy_all(xHiDHix_all_g, xHiDHix_all_e, QixHiy,
                         xHiDHixQixHiy_all_g, xHiDHixQixHiy_all_e);

  Calc_xHiDHiDHiy_all(v_size, eval, Hi, xHi, Hiy, xHiDHiDHiy_all_gg, xHiDHiDHiy_all_ee, xHiDHiDHiy_all_ge);
  Calc_xHiDHiDHix_all(v_size, eval, Hi, xHi, xHiDHiDHix_all_gg, xHiDHiDHix_all_ee, xHiDHiDHix_all_ge);

  // Calculate QixHiDHiy_all, QixHiDHix_all and QixHiDHixQixHiy_all.
  Calc_QiVec_all(Qi, xHiDHiy_all_g, xHiDHiy_all_e, QixHiDHiy_all_g, QixHiDHiy_all_e);
  Calc_QiVec_all(Qi, xHiDHixQixHiy_all_g, xHiDHixQixHiy_all_e, QixHiDHixQixHiy_all_g, QixHiDHixQixHiy_all_e);
  Calc_QiMat_all(Qi, xHiDHix_all_g, xHiDHix_all_e, QixHiDHix_all_g, QixHiDHix_all_e);

  double tHiD_g, tHiD_e, tPD_g, tPD_e, tHiDHiD_gg, tHiDHiD_ee;
  double tHiDHiD_ge, tPDPD_gg, tPDPD_ee, tPDPD_ge;
  double yPDPy_g, yPDPy_e, yPDPDPy_gg, yPDPDPy_ee, yPDPDPy_ge;

  // Calculate gradient and Hessian for Vg.
  for (size_t i1 = 0; i1 < d_size; i1++) {
    for (size_t j1 = 0; j1 < d_size; j1++) {
      if (j1 < i1) {
        continue;
      }
      v1 = GetIndex(i1, j1, d_size);

      Calc_yPDPy(eval, Hiy, QixHiy, xHiDHiy_all_g, xHiDHiy_all_e, xHiDHixQixHiy_all_g, xHiDHixQixHiy_all_e, i1, j1, yPDPy_g, yPDPy_e);

      if (func_name == 'R' || func_name == 'r') {
        Calc_tracePD(eval, Qi, Hi, xHiDHix_all_g, xHiDHix_all_e, i1, j1, tPD_g, tPD_e);

        dev1_g = -0.5 * tPD_g + 0.5 * yPDPy_g;
        dev1_e = -0.5 * tPD_e + 0.5 * yPDPy_e;
      } else {
        Calc_traceHiD(eval, Hi, i1, j1, tHiD_g, tHiD_e);

        dev1_g = -0.5 * tHiD_g + 0.5 * yPDPy_g;
        dev1_e = -0.5 * tHiD_e + 0.5 * yPDPy_e;
      }

      gradient.elements[v1] = dev1_g;
      gradient.elements[v1 + v_size] = dev1_e;

      for (size_t i2 = 0; i2 < d_size; i2++) {
        for (size_t j2 = 0; j2 < d_size; j2++) {
          if (j2 < i2) {
            continue;
          }
          v2 = GetIndex(i2, j2, d_size);

          if (v2 < v1) {
            continue;
          }

          Calc_yPDPDPy(eval, Hi, xHi, Hiy, QixHiy, xHiDHiy_all_g, xHiDHiy_all_e,
                       QixHiDHiy_all_g, QixHiDHiy_all_e, xHiDHixQixHiy_all_g,
                       xHiDHixQixHiy_all_e, QixHiDHixQixHiy_all_g,
                       QixHiDHixQixHiy_all_e, xHiDHiDHiy_all_gg,
                       xHiDHiDHiy_all_ee, xHiDHiDHiy_all_ge, xHiDHiDHix_all_gg,
                       xHiDHiDHix_all_ee, xHiDHiDHix_all_ge, i1, j1, i2, j2,
                       yPDPDPy_gg, yPDPDPy_ee, yPDPDPy_ge);

          // AI for REML.
          if (func_name == 'R' || func_name == 'r') {

            Calc_tracePDPD(eval, Qi, Hi, xHi, QixHiDHix_all_g, QixHiDHix_all_e,
                           xHiDHiDHix_all_gg, xHiDHiDHix_all_ee,
                           xHiDHiDHix_all_ge, i1, j1, i2, j2, tPDPD_gg,
                           tPDPD_ee, tPDPD_ge);

            dev2_gg = 0.5 * tPDPD_gg - yPDPDPy_gg;
            dev2_ee = 0.5 * tPDPD_ee - yPDPDPy_ee;
            dev2_ge = 0.5 * tPDPD_ge - yPDPDPy_ge;
          } else {
            Calc_traceHiDHiD(eval, Hi, i1, j1, i2, j2, tHiDHiD_gg, tHiDHiD_ee,
                             tHiDHiD_ge);

            dev2_gg = 0.5 * tHiDHiD_gg - yPDPDPy_gg;
            dev2_ee = 0.5 * tHiDHiD_ee - yPDPDPy_ee;
            dev2_ge = 0.5 * tHiDHiD_ge - yPDPDPy_ge;
          }

          // Set up Hessian.
          Hessian.set(v1, v2, dev2_gg);
          Hessian.set(v1 + v_size, v2 + v_size, dev2_ee);
          Hessian.set(v1, v2 + v_size, dev2_ge);
          Hessian.set(v2 + v_size, v1, dev2_ge);

          if (v1 != v2) {
            Hessian.set(v2, v1, dev2_gg);
            Hessian.set(v2 + v_size, v1 + v_size, dev2_ee);
            Hessian.set(v2, v1 + v_size, dev2_ge);
            Hessian.set(v1 + v_size, v2, dev2_ge);
          }
        }
      }
    }
  }

  writeln("setting up Hessian_inv");

  writeln(Hessian);
  Hessian_inv = Hessian.inverse();
  // Calculate Edgeworth correction factors after inverting
  // Hessian.
  if (c_size > 1) {
    CalcCRT(Hessian_inv, Qi, QixHiDHix_all_g, QixHiDHix_all_e,
            xHiDHiDHix_all_gg, xHiDHiDHix_all_ee, xHiDHiDHix_all_ge, d_size,
            crt_a, crt_b, crt_c);
  } else {
    crt_a = 0.0;
    crt_b = 0.0;
    crt_c = 0.0;
  }

  writeln("crt_a => ", crt_a);
  writeln("crt_b => ", crt_b);
  writeln("crt_c => ", crt_c);

  return;
}

// Calculate (xHiDHiy) for every pair (i,j).
void Calc_xHiDHiy_all(const DMatrix eval, const DMatrix xHi, const DMatrix Hiy,
                      ref DMatrix xHiDHiy_all_g, ref DMatrix xHiDHiy_all_e) {
  writeln("in Calc_xHiDHiy_all");

  xHiDHiy_all_g = zeros_dmatrix(xHiDHiy_all_g.shape[0], xHiDHiy_all_g.shape[1]);
  xHiDHiy_all_e = zeros_dmatrix(xHiDHiy_all_e.shape[0], xHiDHiy_all_e.shape[1]);

  size_t d_size = Hiy.shape[0];
  size_t v;

  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j < d_size; j++) {
      if (j < i) {
        continue;
      }
      v = GetIndex(i, j, d_size);

      DMatrix xHiDHiy_g = zeros_dmatrix(xHiDHiy_all_g.shape[0], 1 );
      DMatrix xHiDHiy_e = zeros_dmatrix(xHiDHiy_all_e.shape[0], 1 );

      Calc_xHiDHiy(eval, xHi, Hiy, i, j, xHiDHiy_g, xHiDHiy_e);
      set_col2(xHiDHiy_all_g, v, xHiDHiy_g.T);
      set_col2(xHiDHiy_all_e, v, xHiDHiy_e.T);

    }
  }
  return;
}

// Calculate (xHiDHix) for every pair (i,j).
void Calc_xHiDHix_all(const DMatrix eval, const DMatrix xHi,
                      ref DMatrix xHiDHix_all_g, ref DMatrix xHiDHix_all_e) {
  writeln("in Calc_xHiDHix_all");
  xHiDHix_all_g = zeros_dmatrix(xHiDHix_all_g.shape[0], xHiDHix_all_g.shape[1]);
  xHiDHix_all_e = zeros_dmatrix(xHiDHix_all_e.shape[0], xHiDHix_all_e.shape[1]);

  size_t d_size = xHi.shape[1] / eval.size, dc_size = xHi.shape[0];
  size_t v;

  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j < d_size; j++) {
      if (j < i) {
        continue;
      }
      v = GetIndex(i, j, d_size);

      DMatrix xHiDHix_g = zeros_dmatrix(dc_size, dc_size);
      DMatrix xHiDHix_e = zeros_dmatrix(dc_size, dc_size);
      Calc_xHiDHix(eval, xHi, i, j, xHiDHix_g, xHiDHix_e);
      set_sub_dmatrix2(xHiDHix_all_g, 0, v * dc_size, dc_size, dc_size, xHiDHix_g);
      set_sub_dmatrix2(xHiDHix_all_e, 0, v * dc_size, dc_size, dc_size, xHiDHix_e);
    }
  }
  return;
}

// Calculate (xHiDHiy) for every pair (i,j).
void Calc_xHiDHiDHiy_all(const size_t v_size, const DMatrix eval, const DMatrix Hi, const DMatrix xHi,
                         const DMatrix Hiy, ref DMatrix xHiDHiDHiy_all_gg,
                         ref DMatrix xHiDHiDHiy_all_ee, ref DMatrix xHiDHiDHiy_all_ge) {
  writeln("in Calc_xHiDHiDHiy_all");

  xHiDHiDHiy_all_gg = zeros_dmatrix(xHiDHiDHiy_all_gg.shape[0], xHiDHiDHiy_all_gg.shape[1]);
  xHiDHiDHiy_all_ee = zeros_dmatrix(xHiDHiDHiy_all_ee.shape[0], xHiDHiDHiy_all_ee.shape[1]);
  xHiDHiDHiy_all_ge = zeros_dmatrix(xHiDHiDHiy_all_ge.shape[0], xHiDHiDHiy_all_ge.shape[1]);

  size_t d_size = Hiy.shape[0];
  size_t v1, v2;

  for (size_t i1 = 0; i1 < d_size; i1++) {
    for (size_t j1 = 0; j1 < d_size; j1++) {
      if (j1 < i1) {
        continue;
      }
      v1 = GetIndex(i1, j1, d_size);

      for (size_t i2 = 0; i2 < d_size; i2++) {
        for (size_t j2 = 0; j2 < d_size; j2++) {
          if (j2 < i2) {
            continue;
          }
          v2 = GetIndex(i2, j2, d_size);

          DMatrix xHiDHiDHiy_gg = zeros_dmatrix(xHiDHiDHiy_all_gg.shape[0], 1);
          DMatrix xHiDHiDHiy_ee = zeros_dmatrix(xHiDHiDHiy_all_ee.shape[0], 1);
          DMatrix xHiDHiDHiy_ge = zeros_dmatrix(xHiDHiDHiy_all_ge.shape[0], 1);

          Calc_xHiDHiDHiy(eval, Hi, xHi, Hiy, i1, j1, i2, j2, xHiDHiDHiy_gg, xHiDHiDHiy_ee, xHiDHiDHiy_ge);

          set_col2(xHiDHiDHiy_all_gg, v1 * v_size + v2, xHiDHiDHiy_gg.T);
          set_col2(xHiDHiDHiy_all_ee, v1 * v_size + v2, xHiDHiDHiy_ee.T);
          set_col2(xHiDHiDHiy_all_ge, v1 * v_size + v2, xHiDHiDHiy_ge.T);

        }
      }
    }
  }
  return;
}

// Calculate (xHiDHix) for every pair (i,j).
void Calc_xHiDHiDHix_all(const size_t v_size, const DMatrix eval,
                         const DMatrix Hi, const DMatrix xHi,
                         ref DMatrix xHiDHiDHix_all_gg,
                         ref DMatrix xHiDHiDHix_all_ee,
                         ref DMatrix xHiDHiDHix_all_ge) {
  writeln("in Calc_xHiDHiDHix_all");
  xHiDHiDHix_all_gg = zeros_dmatrix(xHiDHiDHix_all_gg.shape[0], xHiDHiDHix_all_gg.shape[1]);
  xHiDHiDHix_all_ee = zeros_dmatrix(xHiDHiDHix_all_ee.shape[0], xHiDHiDHix_all_ee.shape[1]);
  xHiDHiDHix_all_ge = zeros_dmatrix(xHiDHiDHix_all_ge.shape[0], xHiDHiDHix_all_ge.shape[1]);

  size_t d_size = xHi.shape[1] / eval.size, dc_size = xHi.shape[0];
  size_t v1, v2;

  for (size_t i1 = 0; i1 < d_size; i1++) {
    for (size_t j1 = 0; j1 < d_size; j1++) {
      if (j1 < i1) {
        continue;
      }
      v1 = GetIndex(i1, j1, d_size);

      for (size_t i2 = 0; i2 < d_size; i2++) {
        for (size_t j2 = 0; j2 < d_size; j2++) {
          if (j2 < i2) {
            continue;
          }
          v2 = GetIndex(i2, j2, d_size);

          if (v2 < v1) {
            continue;
          }

          DMatrix xHiDHiDHix_gg1 = zeros_dmatrix(dc_size, dc_size);
          DMatrix xHiDHiDHix_ee1 = zeros_dmatrix(dc_size, dc_size);
          DMatrix xHiDHiDHix_ge1 = zeros_dmatrix(dc_size, dc_size);

          Calc_xHiDHiDHix(eval, Hi, xHi, i1, j1, i2, j2, xHiDHiDHix_gg1, xHiDHiDHix_ee1, xHiDHiDHix_ge1);

          set_sub_dmatrix2( xHiDHiDHix_all_gg, 0, (v1 * v_size + v2) * dc_size, dc_size, dc_size, xHiDHiDHix_gg1);
          set_sub_dmatrix2( xHiDHiDHix_all_ee, 0, (v1 * v_size + v2) * dc_size, dc_size, dc_size, xHiDHiDHix_ee1);
          set_sub_dmatrix2( xHiDHiDHix_all_ge, 0, (v1 * v_size + v2) * dc_size, dc_size, dc_size, xHiDHiDHix_ge1);


          if (v2 != v1) {
            set_sub_dmatrix2( xHiDHiDHix_all_gg, 0, (v2 * v_size + v1) * dc_size, dc_size, dc_size, xHiDHiDHix_gg1);
            set_sub_dmatrix2( xHiDHiDHix_all_ee, 0, (v2 * v_size + v1) * dc_size, dc_size, dc_size, xHiDHiDHix_ee1);
            set_sub_dmatrix2( xHiDHiDHix_all_ge, 0, (v2 * v_size + v1) * dc_size, dc_size, dc_size, xHiDHiDHix_ge1);
          }
        }
      }
    }
  }

  return;
}

// Calculate (xHiDHix)Qi(xHiy) for every pair (i,j).
void Calc_xHiDHixQixHiy_all(const DMatrix xHiDHix_all_g,
                            const DMatrix xHiDHix_all_e,
                            const DMatrix QixHiy,
                            ref DMatrix xHiDHixQixHiy_all_g,
                            ref DMatrix xHiDHixQixHiy_all_e) {
  writeln("in Calc_xHiDHixQixHiy_all");
  size_t dc_size = xHiDHix_all_g.shape[0];
  size_t v_size = xHiDHix_all_g.shape[1] / dc_size;

  for (size_t i = 0; i < v_size; i++) {
    DMatrix xHiDHix_g = get_sub_dmatrix( xHiDHix_all_g, 0, i * dc_size, dc_size, dc_size);
    DMatrix xHiDHix_e = get_sub_dmatrix( xHiDHix_all_e, 0, i * dc_size, dc_size, dc_size);

    DMatrix xHiDHixQixHiy_g = get_col(xHiDHixQixHiy_all_g, i);
    DMatrix xHiDHixQixHiy_e = get_col(xHiDHixQixHiy_all_e, i);

    xHiDHixQixHiy_g = matrix_mult(xHiDHix_g, QixHiy);
    xHiDHixQixHiy_e = matrix_mult(xHiDHix_e, QixHiy);

    set_col2(xHiDHixQixHiy_all_g, i, xHiDHixQixHiy_g);
    set_col2(xHiDHixQixHiy_all_e, i, xHiDHixQixHiy_e);
  }
  return;
}

// Calculate Qi(xHiDHiy) and Qi(xHiDHix)Qi(xHiy) for each pair of i,j (i<=j).
void Calc_QiVec_all(const DMatrix Qi, const DMatrix vec_all_g, const DMatrix vec_all_e,
                    ref DMatrix Qivec_all_g, ref DMatrix Qivec_all_e) {
  writeln("in Calc_QiVec_all");
  for (size_t i = 0; i < vec_all_g.shape[1]; i++) {
    DMatrix vec_g = get_col(vec_all_g, i);
    DMatrix vec_e = get_col(vec_all_e, i);

    DMatrix Qivec_g = matrix_mult(Qi, vec_g);
    DMatrix Qivec_e = matrix_mult(Qi, vec_e);

    set_col2(Qivec_all_g, i, Qivec_g);
    set_col2(Qivec_all_e, i, Qivec_e);

  }

  return;
}

// Calculate Qi(xHiDHix) for each pair of i,j (i<=j).
void Calc_QiMat_all(const DMatrix Qi, const DMatrix mat_all_g,
                    const DMatrix mat_all_e, ref DMatrix Qimat_all_g,
                    ref DMatrix Qimat_all_e) {
  size_t dc_size = Qi.shape[0];
  size_t v_size = mat_all_g.shape[1] / mat_all_g.shape[0];

  for (size_t i = 0; i < v_size; i++) {
    DMatrix mat_g = get_sub_dmatrix(mat_all_g, 0, i * dc_size, dc_size, dc_size);
    DMatrix mat_e = get_sub_dmatrix(mat_all_e, 0, i * dc_size, dc_size, dc_size);

    DMatrix Qimat_g = matrix_mult(Qi, mat_g);
    DMatrix Qimat_e = matrix_mult(Qi, mat_e);

    set_sub_dmatrix2(Qimat_all_g, 0, i * dc_size, dc_size, dc_size, Qimat_g);
    set_sub_dmatrix2(Qimat_all_e, 0, i * dc_size, dc_size, dc_size, Qimat_e);

  }

  return;
}

// Calculate yPDPy
// yPDPy = y(Hi-HixQixHi)D(Hi-HixQixHi)y
//       = ytHiDHiy - (yHix)Qi(xHiDHiy) - (yHiDHix)Qi(xHiy)
//         + (yHix)Qi(xHiDHix)Qi(xtHiy)
void Calc_yPDPy(const DMatrix eval, const DMatrix Hiy,
                const DMatrix QixHiy, const DMatrix xHiDHiy_all_g,
                const DMatrix xHiDHiy_all_e,
                const DMatrix xHiDHixQixHiy_all_g,
                const DMatrix xHiDHixQixHiy_all_e, const size_t i,
                const size_t j, ref double yPDPy_g, ref double yPDPy_e) {
  writeln("in Calc_yPDPy");

  size_t d_size = Hiy.shape[0];
  size_t v = GetIndex(i, j, d_size);

  double d;

  // First part: ytHiDHiy.
  Calc_yHiDHiy(eval, Hiy, i, j, yPDPy_g, yPDPy_e);

  // Second and third parts: -(yHix)Qi(xHiDHiy)-(yHiDHix)Qi(xHiy)
  DMatrix xHiDHiy_g = get_col(xHiDHiy_all_g, v);
  DMatrix xHiDHiy_e = get_col(xHiDHiy_all_e, v);

  d = vector_ddot(QixHiy, xHiDHiy_g);
  yPDPy_g -= d * 2.0;
  d = vector_ddot(QixHiy, xHiDHiy_e);
  yPDPy_e -= d * 2.0;

  // Fourth part: +(yHix)Qi(xHiDHix)Qi(xHiy).
  DMatrix xHiDHixQixHiy_g = get_col(xHiDHixQixHiy_all_g, v);
  DMatrix xHiDHixQixHiy_e = get_col(xHiDHixQixHiy_all_e, v);

  d = vector_ddot(QixHiy, xHiDHixQixHiy_g);
  yPDPy_g += d;
  d = vector_ddot(QixHiy, xHiDHixQixHiy_e);
  yPDPy_e += d;

  return;
}

void Calc_yPDPDPy(const DMatrix eval, const DMatrix Hi, const DMatrix xHi,
                  const DMatrix Hiy, const DMatrix QixHiy,
                  const DMatrix xHiDHiy_all_g, const DMatrix xHiDHiy_all_e,
                  const DMatrix QixHiDHiy_all_g, const DMatrix QixHiDHiy_all_e,
                  const DMatrix xHiDHixQixHiy_all_g,
                  const DMatrix xHiDHixQixHiy_all_e,
                  const DMatrix QixHiDHixQixHiy_all_g,
                  const DMatrix QixHiDHixQixHiy_all_e,
                  const DMatrix xHiDHiDHiy_all_gg, const DMatrix xHiDHiDHiy_all_ee,
                  const DMatrix xHiDHiDHiy_all_ge, const DMatrix xHiDHiDHix_all_gg,
                  const DMatrix xHiDHiDHix_all_ee, const DMatrix xHiDHiDHix_all_ge,
                  const size_t i1, const size_t j1, const size_t i2, const size_t j2,
                  ref double yPDPDPy_gg, ref double yPDPDPy_ee, ref double yPDPDPy_ge) {
  size_t d_size = Hi.shape[0], dc_size = xHi.shape[0];
  size_t v1 = GetIndex(i1, j1, d_size), v2 = GetIndex(i2, j2, d_size);
  size_t v_size = d_size * (d_size + 1) / 2;

  double d;

  DMatrix xHiDHiDHixQixHiy; // = gsl_vector_alloc(dc_size);

  // First part: yHiDHiDHiy.
  Calc_yHiDHiDHiy(eval, Hi, Hiy, i1, j1, i2, j2, yPDPDPy_gg, yPDPDPy_ee,
                  yPDPDPy_ge);

  // Second and third parts:
  // -(yHix)Qi(xHiDHiDHiy) - (yHiDHiDHix)Qi(xHiy).
  DMatrix xHiDHiDHiy_gg1 = get_col(xHiDHiDHiy_all_gg, v1 * v_size + v2);
  DMatrix xHiDHiDHiy_ee1 = get_col(xHiDHiDHiy_all_ee, v1 * v_size + v2);
  DMatrix xHiDHiDHiy_ge1 = get_col(xHiDHiDHiy_all_ge, v1 * v_size + v2);

  DMatrix xHiDHiDHiy_gg2 = get_col(xHiDHiDHiy_all_gg, v2 * v_size + v1);
  DMatrix xHiDHiDHiy_ee2 = get_col(xHiDHiDHiy_all_ee, v2 * v_size + v1);
  DMatrix xHiDHiDHiy_ge2 = get_col(xHiDHiDHiy_all_ge, v2 * v_size + v1);

  d = vector_ddot(QixHiy, xHiDHiDHiy_gg1);
  yPDPDPy_gg -= d;
  d = vector_ddot(QixHiy, xHiDHiDHiy_ee1);
  yPDPDPy_ee -= d;
  d = vector_ddot(QixHiy, xHiDHiDHiy_ge1);
  yPDPDPy_ge -= d;

  d = vector_ddot(QixHiy, xHiDHiDHiy_gg2);
  yPDPDPy_gg -= d;
  d = vector_ddot(QixHiy, xHiDHiDHiy_ee2);
  yPDPDPy_ee -= d;
  d = vector_ddot(QixHiy, xHiDHiDHiy_ge2);
  yPDPDPy_ge -= d;

  // Fourth part: - (yHiDHix)Qi(xHiDHiy).
  DMatrix xHiDHiy_g1 = get_col(xHiDHiy_all_g, v1);
  DMatrix xHiDHiy_e1 = get_col(xHiDHiy_all_e, v1);
  DMatrix QixHiDHiy_g2 = get_col(QixHiDHiy_all_g, v2);
  DMatrix QixHiDHiy_e2 = get_col(QixHiDHiy_all_e, v2);

  d = vector_ddot(xHiDHiy_g1, QixHiDHiy_g2);
  yPDPDPy_gg -= d;
  d = vector_ddot(xHiDHiy_e1, QixHiDHiy_e2);
  yPDPDPy_ee -= d;
  d = vector_ddot(xHiDHiy_g1, QixHiDHiy_e2);
  yPDPDPy_ge -= d;

  // Fifth and sixth parts:
  //   + (yHix)Qi(xHiDHix)Qi(xHiDHiy) +
  //   (yHiDHix)Qi(xHiDHix)Qi(xHiy)
  DMatrix QixHiDHiy_g1 = get_col(QixHiDHiy_all_g, v1);
  DMatrix QixHiDHiy_e1 = get_col(QixHiDHiy_all_e, v1);

  DMatrix xHiDHixQixHiy_g1 = get_col(xHiDHixQixHiy_all_g, v1);
  DMatrix xHiDHixQixHiy_e1 = get_col(xHiDHixQixHiy_all_e, v1);
  DMatrix xHiDHixQixHiy_g2 = get_col(xHiDHixQixHiy_all_g, v2);
  DMatrix xHiDHixQixHiy_e2 = get_col(xHiDHixQixHiy_all_e, v2);

  d = vector_ddot(xHiDHixQixHiy_g1, QixHiDHiy_g2);
  yPDPDPy_gg += d;
  d = vector_ddot(xHiDHixQixHiy_g2, QixHiDHiy_g1);
  yPDPDPy_gg += d;

  d = vector_ddot(xHiDHixQixHiy_e1, QixHiDHiy_e2);
  yPDPDPy_ee += d;
  d = vector_ddot(xHiDHixQixHiy_e2, QixHiDHiy_e1);
  yPDPDPy_ee += d;

  d = vector_ddot(xHiDHixQixHiy_g1, QixHiDHiy_e2);
  yPDPDPy_ge += d;
  d = vector_ddot(xHiDHixQixHiy_e2, QixHiDHiy_g1);
  yPDPDPy_ge += d;

  // Seventh part: + (yHix)Qi(xHiDHiDHix)Qi(xHiy)
  DMatrix xHiDHiDHix_gg = get_sub_dmatrix(xHiDHiDHix_all_gg, 0, (v1 * v_size + v2) * dc_size, dc_size, dc_size);
  DMatrix xHiDHiDHix_ee = get_sub_dmatrix(xHiDHiDHix_all_ee, 0, (v1 * v_size + v2) * dc_size, dc_size, dc_size);
  DMatrix xHiDHiDHix_ge = get_sub_dmatrix(xHiDHiDHix_all_ge, 0, (v1 * v_size + v2) * dc_size, dc_size, dc_size);

  xHiDHiDHixQixHiy = matrix_mult(xHiDHiDHix_gg, QixHiy);
  d = vector_ddot(xHiDHiDHixQixHiy, QixHiy);
  yPDPDPy_gg += d;
  xHiDHiDHixQixHiy = matrix_mult(xHiDHiDHix_ee, QixHiy);
  d = vector_ddot(xHiDHiDHixQixHiy, QixHiy);
  yPDPDPy_ee += d;
  xHiDHiDHixQixHiy = matrix_mult(xHiDHiDHix_ge, QixHiy);
  d = vector_ddot(xHiDHiDHixQixHiy, QixHiy);
  yPDPDPy_ge += d;

  // Eighth part: - (yHix)Qi(xHiDHix)Qi(xHiDHix)Qi(xHiy).
  DMatrix QixHiDHixQixHiy_g1 = get_col(QixHiDHixQixHiy_all_g, v1);
  DMatrix QixHiDHixQixHiy_e1 = get_col(QixHiDHixQixHiy_all_e, v1);

  d = vector_ddot(QixHiDHixQixHiy_g1, xHiDHixQixHiy_g2);
  yPDPDPy_gg -= d;
  d = vector_ddot(QixHiDHixQixHiy_e1, xHiDHixQixHiy_e2);
  yPDPDPy_ee -= d;
  d = vector_ddot(QixHiDHixQixHiy_g1, xHiDHixQixHiy_e2);
  yPDPDPy_ge -= d;

  return;
}

// Calculate Edgeworth correctation factors for small samples notation
// and method follows Thomas J. Rothenberg, Econometirca 1984; 52 (4)
// M=xHiDHix
void CalcCRT(const DMatrix Hessian_inv, const DMatrix Qi,
             const DMatrix QixHiDHix_all_g,
             const DMatrix QixHiDHix_all_e,
             const DMatrix xHiDHiDHix_all_gg,
             const DMatrix xHiDHiDHix_all_ee,
             const DMatrix xHiDHiDHix_all_ge, const size_t d_size,
             ref double crt_a, ref double crt_b, ref double crt_c) {
  writeln("in CalcCRT");
  crt_a = 0.0;
  crt_b = 0.0;
  crt_c = 0.0;

  size_t dc_size = Qi.shape[0], v_size = Hessian_inv.shape[0] / 2;
  size_t c_size = dc_size / d_size;
  double h_gg, h_ge, h_ee, d, B = 0.0, C = 0.0, D = 0.0;
  double trCg1, trCe1, trCg2, trCe2, trB_gg, trB_ge, trB_ee;
  double trCC_gg, trCC_ge, trCC_ee, trD_gg = 0.0, trD_ge = 0.0, trD_ee = 0.0;

  DMatrix QiMQi_g1 = zeros_dmatrix(dc_size, dc_size);
  DMatrix QiMQi_e1 = zeros_dmatrix(dc_size, dc_size);
  DMatrix QiMQi_g2 = zeros_dmatrix(dc_size, dc_size);
  DMatrix QiMQi_e2 = zeros_dmatrix(dc_size, dc_size);

  DMatrix QiMQisQisi_g1 = zeros_dmatrix(d_size, d_size);
  DMatrix QiMQisQisi_e1 = zeros_dmatrix(d_size, d_size);
  DMatrix QiMQisQisi_g2 = zeros_dmatrix(d_size, d_size);
  DMatrix QiMQisQisi_e2 = zeros_dmatrix(d_size, d_size);

  DMatrix QiMQiMQi_gg = zeros_dmatrix(dc_size, dc_size);
  DMatrix QiMQiMQi_ge = zeros_dmatrix(dc_size, dc_size);
  DMatrix QiMQiMQi_ee = zeros_dmatrix(dc_size, dc_size);

  DMatrix QiMMQi_gg = zeros_dmatrix(dc_size, dc_size);
  DMatrix QiMMQi_ge = zeros_dmatrix(dc_size, dc_size);
  DMatrix QiMMQi_ee = zeros_dmatrix(dc_size, dc_size);

  DMatrix Qi_si = zeros_dmatrix(d_size, d_size);

  DMatrix M_dd = zeros_dmatrix(d_size, d_size);
  DMatrix M_dcdc = zeros_dmatrix(dc_size, dc_size);

  DMatrix Qi_s = get_sub_dmatrix( Qi, (c_size - 1) * d_size, (c_size - 1) * d_size, d_size, d_size);

  //writeln(Qi);
  Qi_si = Qi_s.inverse();

  // Calculate correction factors.
  for (size_t v1 = 0; v1 < v_size; v1++) {

    // Calculate Qi(xHiDHix)Qi, and subpart of it.
    DMatrix QiM_g1 = get_sub_dmatrix(QixHiDHix_all_g, 0, v1 * dc_size, dc_size, dc_size);
    DMatrix QiM_e1 = get_sub_dmatrix(QixHiDHix_all_e, 0, v1 * dc_size, dc_size, dc_size);

    QiMQi_g1 = matrix_mult(QiM_g1, Qi);
    QiMQi_e1 = matrix_mult(QiM_e1, Qi);

    //gsl_matrix_view
    DMatrix QiMQi_g1_s = get_sub_dmatrix(QiMQi_g1, (c_size - 1) * d_size, (c_size - 1) * d_size, d_size, d_size);
    //gsl_matrix_view
    DMatrix QiMQi_e1_s = get_sub_dmatrix(QiMQi_e1, (c_size - 1) * d_size, (c_size - 1) * d_size, d_size, d_size);

    // Calculate trCg1 and trCe1.
    QiMQisQisi_g1 = matrix_mult(QiMQi_g1_s, Qi_si);
    trCg1 = 0.0;
    for (size_t k = 0; k < d_size; k++) {
      trCg1 -= QiMQisQisi_g1.accessor(k, k);
    }

    QiMQisQisi_e1 = matrix_mult(QiMQi_e1_s, Qi_si);
    trCe1 = 0.0;
    for (size_t k = 0; k < d_size; k++) {
      trCe1 -= QiMQisQisi_e1.accessor(k, k);
    }

    for (size_t v2 = 0; v2 < v_size; v2++) {
      if (v2 < v1) {
        continue;
      }

      // Calculate Qi(xHiDHix)Qi, and subpart of it.
      //gsl_matrix_const_view
      DMatrix QiM_g2 = get_sub_dmatrix(QixHiDHix_all_g, 0, v2 * dc_size, dc_size, dc_size);
      //gsl_matrix_const_view
      DMatrix QiM_e2 = get_sub_dmatrix(QixHiDHix_all_e, 0, v2 * dc_size, dc_size, dc_size);

      QiMQi_g2 = matrix_mult(QiM_g2, Qi);
      QiMQi_e2 = matrix_mult(QiM_e2, Qi);

      //gsl_matrix_view
      DMatrix QiMQi_g2_s = get_sub_dmatrix(QiMQi_g2, (c_size - 1) * d_size, (c_size - 1) * d_size, d_size, d_size);
      //gsl_matrix_view
      DMatrix QiMQi_e2_s = get_sub_dmatrix(QiMQi_e2, (c_size - 1) * d_size, (c_size - 1) * d_size, d_size, d_size);

      // Calculate trCg2 and trCe2.
      QiMQisQisi_g2 = matrix_mult(QiMQi_g2_s, Qi_si);
      trCg2 = 0.0;
      for (size_t k = 0; k < d_size; k++) {
        trCg2 -= QiMQisQisi_g2.accessor(k, k);
      }

      QiMQisQisi_e2 = matrix_mult(QiMQi_e2_s, Qi_si);
      trCe2 = 0.0;
      for (size_t k = 0; k < d_size; k++) {
        trCe2 -= QiMQisQisi_e2.accessor(k, k);
      }

      // Calculate trCC_gg, trCC_ge, trCC_ee.
      M_dd = matrix_mult(QiMQisQisi_g1, QiMQisQisi_g2);
      trCC_gg = 0.0;
      for (size_t k = 0; k < d_size; k++) {
        trCC_gg += M_dd.accessor(k, k);
      }

      M_dd = matrix_mult(QiMQisQisi_g1, QiMQisQisi_e2);
      M_dd = matrix_mult(QiMQisQisi_e1, QiMQisQisi_g2);
      trCC_ge = 0.0;
      for (size_t k = 0; k < d_size; k++) {
        trCC_ge += M_dd.accessor(k, k);
      }

      M_dd = matrix_mult(QiMQisQisi_e1, QiMQisQisi_e2);
      trCC_ee = 0.0;
      for (size_t k = 0; k < d_size; k++) {
        trCC_ee += M_dd.accessor(k, k);
      }

      // Calculate Qi(xHiDHix)Qi(xHiDHix)Qi, and subpart of it.
       QiMQiMQi_gg = matrix_mult(QiM_g1, QiMQi_g2);
       QiMQiMQi_ge = matrix_mult(QiM_g1, QiMQi_e2);
       QiMQiMQi_ge = matrix_mult(QiM_e1, QiMQi_g2);
       QiMQiMQi_ee = matrix_mult(QiM_e1, QiMQi_e2);

      //gsl_matrix_view
      DMatrix QiMQiMQi_gg_s = get_sub_dmatrix(QiMQiMQi_gg, (c_size - 1) * d_size, (c_size - 1) * d_size, d_size, d_size);
      //gsl_matrix_view
      DMatrix QiMQiMQi_ge_s = get_sub_dmatrix(QiMQiMQi_ge, (c_size - 1) * d_size, (c_size - 1) * d_size, d_size, d_size);
      //gsl_matrix_view
      DMatrix QiMQiMQi_ee_s = get_sub_dmatrix(QiMQiMQi_ee, (c_size - 1) * d_size, (c_size - 1) * d_size, d_size, d_size);

      // and part of trB_gg, trB_ge, trB_ee.
      M_dd = matrix_mult(QiMQiMQi_gg_s, Qi_si);
      trB_gg = 0.0;
      for (size_t k = 0; k < d_size; k++) {
        d = M_dd.accessor(k, k);
        trB_gg -= d;
      }

      M_dd = matrix_mult(QiMQiMQi_ge_s, Qi_si);
      trB_ge = 0.0;
      for (size_t k = 0; k < d_size; k++) {
        d = M_dd.accessor(k, k);
        trB_ge -= d;
      }

      M_dd = matrix_mult(QiMQiMQi_ee_s, Qi_si);
      trB_ee = 0.0;
      for (size_t k = 0; k < d_size; k++) {
        d = M_dd.accessor(k, k);
        trB_ee -= d;
      }

      // Calculate Qi(xHiDHiDHix)Qi, and subpart of it.
      //gsl_matrix_const_view
      DMatrix MM_gg = get_sub_dmatrix(xHiDHiDHix_all_gg, 0, (v1 * v_size + v2) * dc_size, dc_size, dc_size);
      //gsl_matrix_const_view
      DMatrix MM_ge = get_sub_dmatrix(xHiDHiDHix_all_ge, 0, (v1 * v_size + v2) * dc_size, dc_size, dc_size);
      //gsl_matrix_const_view
      DMatrix MM_ee = get_sub_dmatrix(xHiDHiDHix_all_ee, 0, (v1 * v_size + v2) * dc_size, dc_size, dc_size);

      M_dcdc    = matrix_mult(Qi,     MM_gg);
      QiMMQi_gg = matrix_mult(M_dcdc, Qi,);
      M_dcdc    = matrix_mult(Qi,     MM_ge);
      QiMMQi_ge = matrix_mult(M_dcdc, Qi,);
      M_dcdc    = matrix_mult(Qi,     MM_ee);
      QiMMQi_ee = matrix_mult(M_dcdc, Qi,);

      //gsl_matrix_view
      DMatrix QiMMQi_gg_s = get_sub_dmatrix(QiMMQi_gg, (c_size - 1) * d_size, (c_size - 1) * d_size, d_size, d_size);
      //gsl_matrix_view
      DMatrix QiMMQi_ge_s = get_sub_dmatrix(QiMMQi_ge, (c_size - 1) * d_size, (c_size - 1) * d_size, d_size, d_size);
      //gsl_matrix_view
      DMatrix QiMMQi_ee_s = get_sub_dmatrix(QiMMQi_ee, (c_size - 1) * d_size, (c_size - 1) * d_size, d_size, d_size);

      // Calculate the other part of trB_gg, trB_ge, trB_ee.
      M_dd = matrix_mult(QiMMQi_gg_s, Qi_si);
      for (size_t k = 0; k < d_size; k++) {
        trB_gg += M_dd.accessor(k, k);
      }
      M_dd = matrix_mult(QiMMQi_ge_s, Qi_si);
      for (size_t k = 0; k < d_size; k++) {
        trB_ge += 2.0 * M_dd.accessor(k, k);
      }
      M_dd = matrix_mult(QiMMQi_ee_s, Qi_si);
      for (size_t k = 0; k < d_size; k++) {
        trB_ee += M_dd.accessor(k, k);
      }

      // Calculate trD_gg, trD_ge, trD_ee.
      trD_gg = 2.0 * trB_gg;
      trD_ge = 2.0 * trB_ge;
      trD_ee = 2.0 * trB_ee;

      // calculate B, C and D
      h_gg = -1.0 * Hessian_inv.accessor(v1, v2);
      h_ge = -1.0 * Hessian_inv.accessor(v1, v2 + v_size);
      h_ee = -1.0 * Hessian_inv.accessor(v1 + v_size, v2 + v_size);

      B += h_gg * trB_gg + h_ge * trB_ge + h_ee * trB_ee;
      C += h_gg * (trCC_gg + 0.5 * trCg1 * trCg2) +
           h_ge * (trCC_ge + 0.5 * trCg1 * trCe2 + 0.5 * trCe1 * trCg2) +
           h_ee * (trCC_ee + 0.5 * trCe1 * trCe2);
      D += h_gg * (trCC_gg + 0.5 * trD_gg) + h_ge * (trCC_ge + 0.5 * trD_ge) +
           h_ee * (trCC_ee + 0.5 * trD_ee);

      if (v1 != v2) {
        B += h_gg * trB_gg + h_ge * trB_ge + h_ee * trB_ee;
        C += h_gg * (trCC_gg + 0.5 * trCg1 * trCg2) +
             h_ge * (trCC_ge + 0.5 * trCg1 * trCe2 + 0.5 * trCe1 * trCg2) +
             h_ee * (trCC_ee + 0.5 * trCe1 * trCe2);
        D += h_gg * (trCC_gg + 0.5 * trD_gg) + h_ge * (trCC_ge + 0.5 * trD_ge) +
             h_ee * (trCC_ee + 0.5 * trD_ee);
      }
    }
  }

  // Calculate a, b, c from B C D.
  crt_a = 2.0 * D - C;
  crt_b = 2.0 * B;
  crt_c = C;

  return;
}
// Update Vg, Ve.
void UpdateVgVe(const DMatrix Hessian_inv, const DMatrix gradient,
                const double step_scale, ref DMatrix V_g, ref DMatrix V_e) {
  size_t v_size = gradient.size / 2, d_size = V_g.shape[0];
  size_t v;

  DMatrix vec_v = zeros_dmatrix(v_size * 2, 1);

  double d;

  // Vectorize Vg and Ve.
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j < d_size; j++) {
      if (j < i) {
        continue;
      }
      v = GetIndex(i, j, d_size);

      d = V_g.accessor(i, j);
      vec_v.elements[v] = d;

      d = V_e.accessor(i, j);
      vec_v.elements[v + v_size] = d;
    }
  }

  //gsl_blas_dgemv(CblasNoTrans, -1.0 * step_scale, Hessian_inv, gradient, 1.0, vec_v);
  DMatrix Hessian_inv_scaled = multiply_dmatrix_num(Hessian_inv, -1*step_scale);
  vec_v = vec_v + matrix_mult(Hessian_inv_scaled, gradient);
  // Save Vg and Ve.
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j < d_size; j++) {

      if (j < i) {
        continue;
      }
      v = GetIndex(i, j, d_size);

      d = vec_v.elements[v];
      V_g.set(i, j, d);
      V_g.set(j, i, d);

      d = vec_v.elements[v + v_size];
      V_e.set(i, j, d);
      V_e.set(j, i, d);
    }
  }

  return;
}

// p-value correction
// mode=1 Wald; mode=2 LRT; mode=3 SCORE;
double PCRT(const size_t mode, const size_t d_size, const double p_value,
            const double crt_a, const double crt_b, const double crt_c) {
  double p_crt = 0.0, chisq_crt = 0.0, q = to!double(d_size);
  double chisq = gsl_cdf_chisq_Qinv(p_value, to!double(d_size));

  if (mode == 1) {
    double a = crt_c / (2.0 * q * (q + 2.0));
    double b = 1.0 + (crt_a + crt_b) / (2.0 * q);
    chisq_crt = (-1.0 * b + sqrt(b * b + 4.0 * a * chisq)) / (2.0 * a);
  } else if (mode == 2) {
    chisq_crt = chisq / (1.0 + crt_a / (2.0 * q));
  } else {
    chisq_crt = chisq;
  }

  p_crt = gsl_cdf_chisq_Q(chisq_crt, to!double(d_size));

  return p_crt;
}

void analyze_plink(const DMatrix U, const DMatrix eval, const DMatrix UtW, const DMatrix UtY,
                    string file_bed, SNPINFO[] snpInfo, int[] indicator_snp, int[] indicator_idv,
                    size_t ni_test) {
  writeln("entering analyze_plink");

  size_t ni_total = snpInfo.length;
  MPHSUMSTAT[] sumStat;

  writeln("bed file =>", file_bed);
  File infile = File(file_bed ~ ".bed");

  double logl_H0 = 0.0, logl_H1 = 0.0, p_wald = 0, p_lrt = 0, p_score = 0;
  double crt_a, crt_b, crt_c;
  int n_bit, n_miss, ci_total, ci_test;
  double geno, x_mean;
  size_t c = 0;
  size_t n_size = UtY.shape[0], d_size = UtY.shape[1], c_size = UtW.shape[1];
  size_t dc_size = d_size * (c_size + 1), v_size = d_size * (d_size + 1) / 2;

  //set VALUE : TODO

  size_t LMM_BATCH_SIZE = 5000;

  // Create a large matrix.
  size_t msize = LMM_BATCH_SIZE;
  DMatrix Xlarge = zeros_dmatrix(U.shape[0], msize);
  DMatrix UtXlarge = zeros_dmatrix(U.shape[0], msize);

  // Large matrices for EM.
  DMatrix U_hat = zeros_dmatrix(d_size, n_size);
  DMatrix E_hat = zeros_dmatrix(d_size, n_size);
  DMatrix OmegaU = zeros_dmatrix(d_size, n_size);
  DMatrix OmegaE = zeros_dmatrix(d_size, n_size);
  DMatrix UltVehiY = zeros_dmatrix(d_size, n_size);
  DMatrix UltVehiBX = zeros_dmatrix(d_size, n_size);
  DMatrix UltVehiU = zeros_dmatrix(d_size, n_size);
  DMatrix UltVehiE = zeros_dmatrix(d_size, n_size);

  // Large matrices for NR.
  // Each dxd block is H_k^{-1}.
  DMatrix Hi_all = zeros_dmatrix(d_size, d_size * n_size);

  // Each column is H_k^{-1}y_k.
  DMatrix Hiy_all = zeros_dmatrix(d_size, n_size);

  // Each dcxdc block is x_k\otimes H_k^{-1}.
  DMatrix xHi_all = zeros_dmatrix(dc_size, d_size * n_size);

  DMatrix Hessian = zeros_dmatrix(v_size * 2, v_size * 2);

  DMatrix x = zeros_dmatrix(1, n_size);

  DMatrix Y = zeros_dmatrix(d_size, n_size);
  Y = UtY.T;

  DMatrix X = zeros_dmatrix(c_size + 1, n_size);
  DMatrix V_g = zeros_dmatrix(d_size, d_size);
  DMatrix V_e = zeros_dmatrix(d_size, d_size);
  DMatrix B = zeros_dmatrix(d_size, c_size + 1);
  DMatrix beta = zeros_dmatrix(1, d_size);
  DMatrix Vbeta = zeros_dmatrix(d_size, d_size);

  // Null estimates for initial values.
  DMatrix V_g_null = zeros_dmatrix(d_size, d_size);
  DMatrix V_e_null = zeros_dmatrix(d_size, d_size);
  DMatrix B_null = zeros_dmatrix(d_size, c_size + 1);
  DMatrix se_B_null = zeros_dmatrix(d_size, c_size);

  DMatrix X_sub = UtW.T;
  //writeln(UtW);
  //exit(0);
  X = set_sub_dmatrix(X, 0, 0, c_size, n_size, X_sub);
  DMatrix B_sub = get_sub_dmatrix(B, 0, 0, d_size, c_size);
  //gsl_matrix_view
  DMatrix xHi_all_sub = get_sub_dmatrix(xHi_all, 0, 0, d_size * c_size, d_size * n_size);
  DMatrix X_row = get_row(X, c_size);

  //gsl_vector_view
  DMatrix B_col = get_col(B, c_size);

  //a_mode(0), k_mode(1), d_pace(DEFAULT_PACE),
  //file_out("result"), path_out("./output/"), miss_level(0.05),
  //maf_level(0.01), hwe_level(0), r2_level(0.9999), l_min(1e-5), l_max(1e5),
  //n_region(10), p_nr(0.001), em_prec(0.0001), nr_prec(0.0001),
  //em_iter(10000), nr_iter(100), crt(0), pheno_mean(0), noconstrain(false),
  //h_min(-1), h_max(-1), h_scale(-1), rho_min(0.0), rho_max(1.0),
  //rho_scale(-1), logp_min(0.0), logp_max(0.0), logp_scale(-1), h_ngrid(10),
  //rho_ngrid(10), s_min(0), s_max(300), w_step(100000), s_step(1000000),
  //r_pace(10), w_pace(1000), n_accept(0), n_mh(10), geo_mean(2000.0),
  //randseed(-1), window_cm(0), window_bp(0), window_ns(0), n_block(200),
  //error(false), ni_subsample(0), n_cvt(1), n_cat(0), n_vc(1),
  //time_total(0.0), time_G(0.0), time_eigen(0.0), time_UtX(0.0),
  //time_UtZ(0.0), time_opt(0.0), time_Omega(0.0) {}

  size_t em_iter = 10000; //check
  double em_prec = 0.0001;
  size_t nr_iter = 100;
  double nr_prec = 0.0001;
  double l_min = 1e-05;
  double l_max = 100000;
  size_t n_region = 10;


  double[] Vg_remle_null;
  double[] Ve_remle_null;
  double[] VVg_remle_null;
  double[] VVe_remle_null;
  double[] beta_remle_null;
  double[] se_beta_remle_null;
  double logl_remle_H0;

  double[] Vg_mle_null;
  double[] Ve_mle_null;
  double[] VVg_mle_null;
  double[] VVe_mle_null;
  double[] beta_mle_null;
  double[] se_beta_mle_null;
  double logl_mle_H0;

  // check
  int a_mode = 4;

  //writeln(X_sub);
  //exit(0);

  MphInitial(em_iter, em_prec, nr_iter, nr_prec, eval, X_sub, Y, l_min, l_max, n_region, V_g, V_e, B_sub);
  set_sub_dmatrix2(B, 0, 0, d_size, c_size, B_sub);

  writeln("Hi_all.shape => ", Hi_all.shape);
  assert(eqeq(V_g, DMatrix([4, 4], [233.838,          0,         0,       0,
                                          0, 0.00604845,         0,       0,
                                          0,          0, 0.0640605,       0,
                                          0,          0,         0, 17.7095])
        ));

  assert(eqeq(V_e, DMatrix([4, 4], [67.0937,        0,        0,       0,
                                          0, 0.010498,        0,       0,
                                          0,        0, 0.254285,       0,
                                          0,        0,        0, 17.5755])
        ));

  assert(eqeq(B, DMatrix([4, 3], [ 7.07432,    0.37419,   0,
                                  -0.0353791,  0.0870001, 0,
                                   0.0122087, -0.0271713, 0,
                                  -2.16772,   -0.380524,  0])));

  logl_H0 = MphEM('R', em_iter, em_prec, eval, X_sub, Y, U_hat, E_hat,
                  OmegaU, OmegaE, UltVehiY, UltVehiBX, UltVehiU, UltVehiE, V_g,
                  V_e, B_sub);

  writeln("OmegaU => ", OmegaU);

  logl_H0 = MphNR('R', nr_iter, nr_prec, eval, X_sub, Y, Hi_all,
                  xHi_all_sub, Hiy_all, V_g, V_e, Hessian, crt_a, crt_b, crt_c);
  set_sub_dmatrix2(B, 0, 0, d_size, c_size, B_sub);


  MphCalcBeta(eval, X_sub, Y, V_g, V_e, UltVehiY, B_sub, se_B_null);

  c = 0;
  Vg_remle_null = [];
  Ve_remle_null = [];
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = i; j < d_size; j++) {
      Vg_remle_null ~= V_g.accessor( i, j);
      Ve_remle_null ~= V_e.accessor( i, j);
      VVg_remle_null ~= Hessian.accessor( c, c);
      VVe_remle_null ~= Hessian.accessor( c + v_size, c + v_size);
      c++;
    }
  }
  beta_remle_null = [];
  se_beta_remle_null = [];
  for (size_t i = 0; i < se_B_null.shape[0]; i++) {
    for (size_t j = 0; j < se_B_null.shape[1]; j++) {
      beta_remle_null ~= B.accessor( i, j);
      se_beta_remle_null ~= se_B_null.accessor( i, j);
    }
  }
  logl_remle_H0 = logl_H0;

  writeln("REMLE estimate for Vg in the null model: ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      write(V_g.accessor(i, j), "\t");
    }
    write("\n");
  }
  //assert(abs(V_g.accessor(0,0) - 242.2079) < 1e-03);
  writeln("se(Vg): ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      c = GetIndex(i, j, d_size);
      write(sqrt(Hessian.accessor(c, c)), "\t");
    }
    write("\n");
  }
  writeln("REMLE estimate for Ve in the null model: ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      write(V_e.accessor( i, j), "\t");
    }
    write("\n");
  }
  writeln("se(Ve): ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      c = GetIndex(i, j, d_size);
      write(sqrt(Hessian.accessor(c + v_size, c + v_size)), "\t");
    }
    write("\n");
  }
  writeln("REMLE likelihood = ", logl_H0);

  logl_H0 = MphEM('L', em_iter, em_prec, eval, X_sub, Y, U_hat, E_hat,
                  OmegaU, OmegaE, UltVehiY, UltVehiBX, UltVehiU, UltVehiE, V_g,
                  V_e, B_sub);
  logl_H0 = MphNR('L', nr_iter, nr_prec, eval, X_sub, Y, Hi_all,
                  xHi_all_sub, Hiy_all, V_g, V_e, Hessian, crt_a, crt_b,
                  crt_c);
  MphCalcBeta(eval, X_sub, Y, V_g, V_e, UltVehiY, B_sub, se_B_null);

  c = 0;
  Vg_mle_null = [];
  Ve_mle_null = [];
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = i; j < d_size; j++) {
      Vg_mle_null ~= V_g.accessor( i, j);
      Ve_mle_null ~= V_e.accessor( i, j);
      VVg_mle_null ~= Hessian.accessor( c, c);
      VVe_mle_null ~= Hessian.accessor( c + v_size, c + v_size);
      c++;
    }
  }
  beta_mle_null = [];
  se_beta_mle_null = [];
  for (size_t i = 0; i < se_B_null.shape[0]; i++) {
    for (size_t j = 0; j < se_B_null.shape[1]; j++) {
      beta_mle_null ~= B.accessor( i, j);
      se_beta_mle_null ~= se_B_null.accessor(i, j);
    }
  }
  logl_mle_H0 = logl_H0;

  writeln("MLE estimate for Vg in the null model: ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      write(V_g.accessor(i, j), "\t");
    }
    write("\n");
  }
  writeln("se(Vg): ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      c = GetIndex(i, j, d_size);
      write(sqrt(Hessian.accessor(c, c)), "\t");
    }
    write("\n");
  }
  writeln("MLE estimate for Ve in the null model: ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      write(V_e.accessor( i, j), "\t");
    }
    write("\n");
  }
  writeln("se(Ve): ");
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j <= i; j++) {
      c = GetIndex(i, j, d_size);
      write(sqrt(Hessian.accessor(c + v_size, c + v_size)), "\t");
    }
    write("\n");
  }
  writeln("MLE likelihood = ", logl_H0);

  double[] v_beta, v_Vg, v_Ve, v_Vbeta;
  for (size_t i = 0; i < d_size; i++) {
    v_beta ~= 0;
  }
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = i; j < d_size; j++) {
      v_Vg ~= 0;
      v_Ve ~= 0;
      v_Vbeta ~= 0;
    }
  }

  V_g_null = V_g.dup_dmatrix;
  V_e_null = V_e.dup_dmatrix;
  B_null   = B.dup_dmatrix;

  // Start reading genotypes and analyze.
  // Calculate n_bit and c, the number of bit for each snp.
  if (ni_total % 4 == 0) {
    n_bit = to!int(ni_total / 4);
  } else {
    n_bit = to!int(ni_total / 4 + 1);
  }

  // Print the first three magic numbers.
  for (int i = 0; i < 3; ++i) {
    auto b = BitArray(8, cast(ulong*)infile.rawRead(new char[1]));
  }

  size_t csnp = 0, t_last = 0;
  for (size_t t = 0; t < indicator_snp.length; ++t) {
    if (indicator_snp[t] == 0) {
      continue;
    }
    t_last++;
  }

  writeln(snpInfo.length);
  for (size_t t = 0; t < snpInfo.length; ++t) {
    if (indicator_snp[t] == 0) {
      continue;
    }

    // n_bit, and 3 is the number of magic numbers.
    infile.seek(t * n_bit + 3);

    // read genotypes
    x_mean = 0.0;
    n_miss = 0;
    ci_total = 0;
    ci_test = 0;
    for (int i = 0; i < n_bit; ++i) {
      auto b = BitArray(8, cast(ulong*)infile.rawRead(new char[1]));

      // Minor allele homozygous: 2.0; major: 0.0;
      for (size_t j = 0; j < 4; ++j) {
        if ((i == (n_bit - 1)) && ci_total == to!int(ni_total)) {
          break;
        }
        if (indicator_idv[ci_total] == 0) {
          ci_total++;
          continue;
        }

        if (b[2 * j] == 0) {
          if (b[2 * j + 1] == 0) {
            x.elements[ci_test] = 2;
            x_mean += 2.0;
          } else {
            x.elements[ci_test] = 1;
            x_mean += 1.0;
          }
        } else {
          if (b[2 * j + 1] == 1) {
            x.elements[ci_test] = 0;
          } else {
            x.elements[ci_test] = -9;
            n_miss++;
          }
        }

        ci_total++;
        ci_test++;
      }
    }

    x_mean /= to!double(ni_test - n_miss);

    for (size_t i = 0; i < ni_test; ++i) {
      geno = x.elements[i];
      if (geno == -9) {
        x.elements[i] = x_mean;
        geno = x_mean;
      }
    }
    //gsl_vector_view
    //DMatrix Xlarge_col = get_col(Xlarge, csnp % msize);
    //gsl_vector_memcpy(Xlarge_col, x);
    set_col2(Xlarge, csnp % msize, x.T);
    csnp++;

    if (csnp % msize == 0 || csnp == t_last) {
      size_t l = 0;
      if (csnp % msize == 0) {
        l = msize;
      } else {
        l = csnp % msize;
      }

      //gsl_matrix_view
      DMatrix Xlarge_sub = get_sub_dmatrix(Xlarge, 0, 0, Xlarge.shape[0], l);
      //gsl_matrix_view
      DMatrix UtXlarge_sub = get_sub_dmatrix(UtXlarge, 0, 0, UtXlarge.shape[0], l);

      UtXlarge_sub = matrix_mult(U.T, Xlarge_sub);
      set_sub_dmatrix2(UtXlarge, 0, 0,  UtXlarge.shape[0], l, UtXlarge_sub);

      Xlarge = zeros_dmatrix(Xlarge.shape[0], Xlarge.shape[1]);

      for (size_t i = 0; i < l; i++) {
        //gsl_vector_view
        //DMatrix UtXlarge_col = get_col(UtXlarge, i);
        //gsl_vector_memcpy(X_row, UtXlarge_col);
        X_row = get_col(UtXlarge, i);

        // Initial values.
        V_g =  V_g_null.dup_dmatrix;
        V_e =  V_e_null.dup_dmatrix;
        B =  B_null.dup_dmatrix;

        // 3 is before 1.
        // Set value : TODO
        double crt;
        size_t p_nr;

        if (a_mode == 3 || a_mode == 4) {
          p_score = MphCalcP(eval, X_row, X_sub, Y, V_g_null, V_e_null, UltVehiY, beta, Vbeta);

          if (p_score < p_nr && crt == 1) {
            logl_H1 = MphNR('R', 1, nr_prec * 10, eval, X, Y, Hi_all, xHi_all,
                            Hiy_all, V_g, V_e, Hessian, crt_a, crt_b, crt_c);
            p_score = PCRT(3, d_size, p_score, crt_a, crt_b, crt_c);
          }
        }

        if (a_mode == 2 || a_mode == 4) {
          logl_H1 = MphEM('L', em_iter / 10, em_prec * 10, eval, X, Y, U_hat,
                          E_hat, OmegaU, OmegaE, UltVehiY, UltVehiBX, UltVehiU,
                          UltVehiE, V_g, V_e, B);

          // Calculate beta and Vbeta.
          p_lrt = MphCalcP(eval, X_row, X_sub, Y, V_g, V_e,
                           UltVehiY, beta, Vbeta);
          p_lrt = gsl_cdf_chisq_Q(2.0 * (logl_H1 - logl_H0), to!double(d_size));

          if (p_lrt < p_nr) {
            logl_H1 =
                MphNR('L', nr_iter / 10, nr_prec * 10, eval, X, Y, Hi_all,
                      xHi_all, Hiy_all, V_g, V_e, Hessian, crt_a, crt_b, crt_c);

            // Calculate beta and Vbeta.
            p_lrt = MphCalcP(eval, X_row, X_sub, Y, V_g, V_e, UltVehiY, beta, Vbeta);
            p_lrt = gsl_cdf_chisq_Q(2.0 * (logl_H1 - logl_H0), to!double(d_size));
            if (crt == 1) {
              p_lrt = PCRT(2, d_size, p_lrt, crt_a, crt_b, crt_c);
            }
          }
        }

        if (a_mode == 1 || a_mode == 4) {
          logl_H1 = MphEM('R', em_iter / 10, em_prec * 10, eval, X, Y, U_hat,
                          E_hat, OmegaU, OmegaE, UltVehiY, UltVehiBX, UltVehiU,
                          UltVehiE, V_g, V_e, B);
          p_wald = MphCalcP(eval, X_row, X_sub, Y, V_g, V_e, UltVehiY, beta, Vbeta);

          if (p_wald < p_nr) {
            logl_H1 = MphNR('R', nr_iter / 10, nr_prec * 10, eval, X, Y, Hi_all,
                         xHi_all, Hiy_all, V_g, V_e, Hessian, crt_a, crt_b, crt_c);
            p_wald = MphCalcP(eval, X_row, X_sub, Y, V_g, V_e,
                              UltVehiY, beta, Vbeta);

            if (crt == 1) {
              p_wald = PCRT(1, d_size, p_wald, crt_a, crt_b, crt_c);
            }
          }
        }


        // Store summary data.
        for (size_t j = 0; j < d_size; j++) {
          v_beta[j] = beta.elements[j];
        }

        c = 0;
        for (size_t k = 0; k < d_size; k++) {
          for (size_t j = k; j < d_size; j++) {
            v_Vg[c] = V_g.accessor( k, j);
            v_Ve[c] = V_e.accessor( k, j);
            v_Vbeta[c] = Vbeta.accessor( k, j);
            c++;
          }
        }

        MPHSUMSTAT SNPs = {v_beta, p_wald, p_lrt, p_score, v_Vg, v_Ve, v_Vbeta};
        sumStat ~= SNPs;
      }
    }
  }

  return;
}

// 'R' for restricted likelihood and 'L' for likelihood.
// 'R' update B and 'L' don't.
// only calculate -0.5*\sum_{k=1}^n|H_k|-0.5yPxy.
double MphCalcLogL(const DMatrix eval, const DMatrix xHiy, const DMatrix D_l,
                   const DMatrix UltVehiY, const DMatrix Qi) {

  size_t n_size = eval.size, d_size = D_l.size, dc_size = Qi.shape[0];
  double logl = 0.0, delta, dl, y, d;

  // Calculate yHiy+log|H_k|.
  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];
    for (size_t i = 0; i < d_size; i++) {
      y = UltVehiY.accessor(i, k);
      dl = D_l.elements[i];
      d = delta * dl + 1.0;

      logl += y * y / d + mlog(d);
    }
  }

  // Calculate the rest of yPxy.
  DMatrix Qiv = matrix_mult(Qi, xHiy);
  d = vector_ddot(xHiy, Qiv);

  logl -= d;

  return -0.5 * logl;
}

// Qi=(\sum_{k=1}^n x_kx_k^T\otimes(delta_k*Dl+I)^{-1} )^{-1}.
double CalcQi(const DMatrix eval, const DMatrix D_l,
              const DMatrix X, ref DMatrix Qi) {
  size_t n_size = eval.size, d_size = D_l.size, dc_size = Qi.shape[0];
  size_t c_size = dc_size / d_size;

  double delta, dl, d1, d2, d, logdet_Q;

  DMatrix Q = zeros_dmatrix(dc_size, dc_size);

  for (size_t i = 0; i < c_size; i++) {
    for (size_t j = 0; j < c_size; j++) {
      for (size_t l = 0; l < d_size; l++) {
        dl = D_l.elements[l];

        if (j < i) {
          d = Q.accessor( j * d_size + l, i * d_size + l);
        } else {
          d = 0.0;
          for (size_t k = 0; k < n_size; k++) {
            d1 = X.accessor( i, k);
            d2 = X.accessor( j, k);
            delta = eval.elements[k];
            d += d1 * d2 / (dl * delta + 1.0); // @@
          }
        }

        Q.set(i * d_size + l, j * d_size + l, d);
      }
    }
  }

  // Calculate LU decomposition of Q, and invert Q and calculate |Q|.
  Qi = Q.inverse;
  logdet_Q = mlog(det(Q));  // factorization is done twice : Scope of improvement

  return logdet_Q;
}

// xHiy=\sum_{k=1}^n x_k\otimes ((delta_k*Dl+I)^{-1}Ul^TVe^{-1/2}y.
void CalcXHiY(const DMatrix eval, const DMatrix D_l,
              const DMatrix X, const DMatrix UltVehiY,
              ref DMatrix xHiy) {
  size_t n_size = eval.size, c_size = X.shape[0], d_size = D_l.size;
  assert(xHiy.is_vector);

  xHiy = zeros_dmatrix(xHiy.shape[0], xHiy.shape[1]);

  double x, delta, dl, y, d;
  for (size_t i = 0; i < d_size; i++) {
    dl = D_l.elements[i];
    for (size_t j = 0; j < c_size; j++) {
      d = 0.0;
      for (size_t k = 0; k < n_size; k++) {
        x = X.accessor(j, k);
        y = UltVehiY.accessor(i, k);

        delta = eval.elements[k];
        d += x * y / (delta * dl + 1.0);
      }
      xHiy.elements[j * d_size + i] = d;
    }
  }

  return;
}

// OmegaU=D_l/(delta Dl+I)^{-1}
// OmegaE=delta D_l/(delta Dl+I)^{-1}
void CalcOmega(const DMatrix eval, const DMatrix D_l,
               ref DMatrix OmegaU, ref DMatrix OmegaE) {
  size_t n_size = eval.size, d_size = D_l.size;
  double delta, dl, d_u, d_e;

  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];
    for (size_t i = 0; i < d_size; i++) {
      dl = D_l.elements[i];

      d_u = dl / (delta * dl + 1.0);  // @@
      d_e = delta * d_u;

      OmegaU.set(i, k, d_u);
      OmegaE.set(i, k, d_e);
    }
  }

  return;
}

void UpdateL_B(const DMatrix X, const DMatrix XXti,
               const DMatrix UltVehiY, const DMatrix UltVehiU,
               ref DMatrix UltVehiBX, ref DMatrix UltVehiB) {
  size_t c_size = X.shape[0], d_size = UltVehiY.shape[0];

  UltVehiBX = dup_dmatrix(UltVehiY);
  UltVehiBX = subtract_dmatrix(UltVehiY, UltVehiU);

  DMatrix YUX = matrix_mult(UltVehiBX, X.T);
  UltVehiB = matrix_mult(YUX, XXti);

  return;
}

void UpdateRL_B(const DMatrix xHiy, const DMatrix Qi, ref DMatrix UltVehiB) {
  assert(xHiy.is_vector);
  size_t d_size = UltVehiB.shape[0], c_size = UltVehiB.shape[1], dc_size = Qi.shape[0];

  // Calculate b=Qiv.
  DMatrix b = matrix_mult(Qi, xHiy);

  for (size_t i = 0; i < c_size; i++) {
    DMatrix b_subcol = get_subvector_dmatrix(b, i * d_size, d_size);
    set_col2(UltVehiB, i,  b_subcol.T);
  }
  return;
}

void UpdateU(const DMatrix OmegaE, const DMatrix UltVehiY,
             const DMatrix UltVehiBX, ref DMatrix UltVehiU) {
  UltVehiU = subtract_dmatrix(UltVehiY, UltVehiBX);
  UltVehiU = slow_multiply_dmatrix(UltVehiU, OmegaE);
  return;
}


void UpdateE(const DMatrix UltVehiY, const DMatrix UltVehiBX,
             const DMatrix UltVehiU, ref DMatrix UltVehiE) {
  UltVehiE = subtract_dmatrix(UltVehiY, UltVehiBX);
  UltVehiE = subtract_dmatrix(UltVehiE, UltVehiU);
  return;
}

void UpdateV(const DMatrix eval, const DMatrix U, const DMatrix E,
             const DMatrix Sigma_uu, const DMatrix Sigma_ee,
             ref DMatrix V_g, ref DMatrix V_e) {
  size_t n_size = eval.size, d_size = U.shape[0];

  V_g = zeros_dmatrix(V_g.shape[0], V_g.shape[1]);
  V_e = zeros_dmatrix(V_e.shape[0], V_e.shape[1]);

  double delta;

  // Calculate the first part: UD^{-1}U^T and EE^T.
  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];
    if (delta == 0) {
      continue;
    }

    //gsl_vector_const_view
    DMatrix U_col = get_col(U, k);
    // IMP
    //gsl_blas_dsyr(CblasUpper, 1.0 / delta, &U_col.vector, V_g);
    V_g = syr(1/delta, U_col, V_g);
  }

  V_e = matrix_mult(E, E.T); // check

  // Copy the upper part to lower part.
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j < i; j++) {
      V_g.set(i, j, V_g.accessor(j, i));
      V_e.set(i, j, V_e.accessor(j, i));
    }
  }

  // Add Sigma.
  V_g = add_dmatrix(V_g, Sigma_uu);
  V_e = add_dmatrix(V_e, Sigma_ee);

  // Scale by 1/n.
  V_g = multiply_dmatrix_num(V_g, 1.0 / to!double(n_size));
  V_e = multiply_dmatrix_num(V_e, 1.0 / to!double(n_size));

  return;
}

void CalcSigma(const char func_name, const DMatrix eval,
               const DMatrix D_l, const DMatrix X,
               const DMatrix OmegaU, const DMatrix OmegaE,
               const DMatrix UltVeh, const DMatrix Qi,
               ref DMatrix Sigma_uu, ref DMatrix Sigma_ee) {
  if(func_name != 'R' && func_name != 'L' && func_name != 'r' && func_name != 'l') {
    writeln("func_name only takes 'R' or 'L': 'R' for log-restricted likelihood, 'L' for log-likelihood.");
    return;
  }

  size_t n_size = eval.size, c_size = X.shape[0];
  size_t d_size = D_l.size, dc_size = Qi.shape[0];

  Sigma_uu = zeros_dmatrix(Sigma_uu.shape[0], Sigma_uu.shape[1]);
  Sigma_ee = zeros_dmatrix(Sigma_ee.shape[0], Sigma_ee.shape[1]);

  double delta, dl, x, d;

  // Calculate the first diagonal term.
  DMatrix Suu_diag = zeros_dmatrix(Sigma_uu.shape[0], 1);
  DMatrix See_diag = zeros_dmatrix(Sigma_ee.shape[0], 1);

  for (size_t k = 0; k < n_size; k++) {
    //gsl_vector_const_view
    DMatrix OmegaU_col = get_col(OmegaU, k);
    //gsl_vector_const_view
    DMatrix OmegaE_col = get_col(OmegaE, k);

    Suu_diag = add_dmatrix(Suu_diag, OmegaU_col);
    See_diag = add_dmatrix(See_diag, OmegaE_col);
  }

  Sigma_uu.set_diagonal(Suu_diag);
  Sigma_ee.set_diagonal(See_diag);

  // Calculate the second term for REML.
  if (func_name == 'R' || func_name == 'r') {
    DMatrix M_u = zeros_dmatrix(dc_size, d_size);
    DMatrix M_e = zeros_dmatrix(dc_size, d_size);

    for (size_t k = 0; k < n_size; k++) {
      delta = eval.elements[k];

      for (size_t i = 0; i < d_size; i++) {
        dl =D_l.elements[i];
        for (size_t j = 0; j < c_size; j++) {
          x = X.accessor(j, k);
          d = x / (delta * dl + 1.0);
          M_e.set(j * d_size + i, i, d);
          M_u.set(j * d_size + i, i, d * dl);
        }
      }

      DMatrix QiM = matrix_mult(Qi, M_u);
      Sigma_uu = matrix_mult(multiply_dmatrix_num(M_u, delta).T, QiM) + Sigma_uu; //check
      QiM = matrix_mult(Qi, M_e);
      Sigma_ee = matrix_mult(M_e.T, QiM) + Sigma_ee; //check
    }
  }

  // Multiply both sides by VehUl.
  DMatrix M = matrix_mult(Sigma_uu, UltVeh);
  Sigma_uu = matrix_mult(UltVeh.T, M);
  M = matrix_mult(Sigma_ee, UltVeh);
  Sigma_ee = matrix_mult(UltVeh.T, M);

  return;
}

// Calculate all Hi and return logdet_H=\sum_{k=1}^{n}log|H_k|
// and calculate Qi and return logdet_Q
// and calculate yPy.
void CalcHiQi(const DMatrix eval, const DMatrix X,
              const DMatrix V_g, const DMatrix V_e, ref DMatrix Hi_all,
              ref DMatrix Qi, ref double logdet_H, ref double logdet_Q) {
  writeln("in CalcHiQi");
  Hi_all = zeros_dmatrix(Hi_all.shape[0], Hi_all.shape[1]);
  Qi = zeros_dmatrix(Qi.shape[0], Qi.shape[1]);
  logdet_H = 0.0;
  logdet_Q = 0.0;

  size_t n_size = eval.size, c_size = X.shape[0], d_size = V_g.shape[0];
  double logdet_Ve = 0.0, delta, dl, d;

  DMatrix mat_dd;
  DMatrix UltVeh = zeros_dmatrix(d_size, d_size);
  DMatrix UltVehi = zeros_dmatrix(d_size, d_size);
  DMatrix D_l = zeros_dmatrix(1, d_size);

  // Calculate D_l, UltVeh and UltVehi.
  logdet_Ve = EigenProc(V_g, V_e, D_l, UltVeh, UltVehi);


  // Calculate each Hi and log|H_k|.
  logdet_H = to!double(n_size) * logdet_Ve;
  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];

    mat_dd = UltVehi.dup_dmatrix;
    for (size_t i = 0; i < d_size; i++) {
      dl = D_l.elements[i];
      d = delta * dl + 1.0;

      //gsl_vector_view
      DMatrix mat_row = get_row(mat_dd, i);
      mat_row = divide_dmatrix_num(mat_row, d); // @@
      set_row2(mat_dd, i , mat_row);

      logdet_H += mlog(d);
    }

    DMatrix Hi_k = matrix_mult(UltVehi.T, mat_dd);
    set_sub_dmatrix2(Hi_all, 0, k * d_size, d_size, d_size, Hi_k);
    //writeln("Hi_all", Hi_all);
    //exit(0);
  }

  // Calculate Qi, and multiply I\o times UtVeh on both side and
  // calculate logdet_Q, don't forget to substract
  // c_size*logdet_Ve.
  logdet_Q = CalcQi(eval, D_l, X, Qi) - to!double(c_size) * logdet_Ve;

  for (size_t i = 0; i < c_size; i++) {
    for (size_t j = 0; j < c_size; j++) {
      DMatrix Qi_sub = get_sub_dmatrix(Qi, i * d_size, j * d_size, d_size, d_size);
      if (j < i) {
        DMatrix Qi_sym = get_sub_dmatrix(Qi, j * d_size, i * d_size, d_size, d_size);
        Qi_sub = Qi_sym.T;
      } else {
        mat_dd = matrix_mult(Qi_sub, UltVeh);
        Qi_sub = matrix_mult(UltVeh.T, mat_dd);
      }
      set_sub_dmatrix2(Qi, i * d_size, j * d_size, d_size, d_size, Qi_sub);
    }
  }
  return;
}


// Calculate all Hiy.
void Calc_Hiy_all(const DMatrix Y, const DMatrix Hi_all, ref DMatrix Hiy_all) {
  writeln("in Calc_Hiy_all");
  Hiy_all = zeros_dmatrix(Hiy_all.shape[0], Hiy_all.shape[1]);

  size_t n_size = Y.shape[1], d_size = Y.shape[0];

  for (size_t k = 0; k < n_size; k++) {
    DMatrix Hi_k = get_sub_dmatrix(Hi_all, 0, k * d_size, d_size, d_size);
    DMatrix y_k = get_col(Y, k);
    DMatrix Hiy_k = matrix_mult(Hi_k, y_k);
    set_col2(Hiy_all, k, Hiy_k);
  }
  return;
}

// Calculate all xHi.
void Calc_xHi_all(const DMatrix X, const DMatrix Hi_all, ref DMatrix xHi_all) {
  writeln("in Calc_xHi_all");
  xHi_all = zeros_dmatrix(xHi_all.shape[0], xHi_all.shape[1]);

  size_t n_size = X.shape[1], c_size = X.shape[0], d_size = Hi_all.shape[0];

  double d;

  for (size_t k = 0; k < n_size; k++) {
    DMatrix Hi_k = get_sub_dmatrix(Hi_all, 0, k * d_size, d_size, d_size);

    for (size_t i = 0; i < c_size; i++) {
      d = X.accessor(i, k);
      DMatrix xHi_sub = multiply_dmatrix_num(Hi_k, d);
      set_sub_dmatrix2(xHi_all,  i * d_size, k * d_size, d_size, d_size, xHi_sub);
    }
  }

  return;
}

double Calc_yHiy(const DMatrix Y, const DMatrix Hiy_all) {
  writeln("in Calc_yHiy");
  double yHiy = 0.0, d;
  size_t n_size = Y.shape[1];

  for (size_t k = 0; k < n_size; k++) {
    DMatrix y_k = get_col(Y, k);
    DMatrix Hiy_k = get_col(Hiy_all, k);
    d = vector_ddot(Hiy_k, y_k);
    yHiy += d;
  }

  return yHiy;
}

// Calculate the vector xHiy.
void Calc_xHiy(const DMatrix Y, const DMatrix xHi, ref DMatrix xHiy) {
  //xHiy is a vector;
  writeln("in Calc_xHiy");
  xHiy = zeros_dmatrix(xHiy.shape[0], xHiy.shape[1]);

  size_t n_size = Y.shape[1], d_size = Y.shape[0], dc_size = xHi.shape[0];

  for (size_t k = 0; k < n_size; k++) {
    DMatrix xHi_k = get_sub_dmatrix(xHi, 0, k * d_size, dc_size, d_size);
    DMatrix y_k = get_col(Y, k);
    xHiy = xHiy + matrix_mult(xHi_k, y_k); // may need changes
  }

  return;
}

// Below are functions for EM algorithm.
double EigenProc(const DMatrix V_g, const DMatrix V_e, ref DMatrix D_l,
                 ref DMatrix UltVeh, ref DMatrix UltVehi) {
  //writeln("in EigenProc");
  size_t d_size = V_g.shape[0];
  double d, logdet_Ve = 0.0;

  // Eigen decomposition of V_e.
  DMatrix Lambda = zeros_dmatrix(d_size, d_size);
  DMatrix V_e_temp = zeros_dmatrix(d_size, d_size);
  DMatrix V_e_h = zeros_dmatrix(d_size, d_size);
  DMatrix V_e_hi = zeros_dmatrix(d_size, d_size);
  DMatrix VgVehi = zeros_dmatrix(d_size, d_size);
  DMatrix U_l = zeros_dmatrix(d_size, d_size);

  //gsl_matrix_memcpy(V_e_temp, V_e);
  EigenDecomp(cast(DMatrix)V_e, U_l, D_l, 0);

  // Calculate V_e_h and V_e_hi.
  V_e_h = zeros_dmatrix(V_e_h.shape[0], V_e_h.shape[1]);
  V_e_hi = zeros_dmatrix(V_e_hi.shape[0], V_e_hi.shape[1]);
  for (size_t i = 0; i < d_size; i++) {
    d = D_l.elements[i];
    if (d <= 0) {
      continue;
    }
    logdet_Ve += mlog(d);

    DMatrix U_col = get_col(U_l, i);
    d = sqrt(d);
    V_e_h = syr(d, U_col, V_e_h);

    d = 1.0 / d;
    V_e_hi = syr(d, U_col, V_e_hi);
  }

  // Copy the upper part to lower part.
  for (size_t i = 0; i < d_size; i++) {
    for (size_t j = 0; j < i; j++) {
      V_e_h.set(i, j, V_e_h.accessor(j, i));
      V_e_hi.set(i, j, V_e_hi.accessor(j, i));
    }
  }

  // Calculate Lambda=V_ehi V_g V_ehi.
  VgVehi = matrix_mult(V_g, V_e_hi);
  Lambda = matrix_mult(V_e_hi, VgVehi);

  // Eigen decomposition of Lambda.
  EigenDecomp_Zeroed(Lambda, U_l, D_l, 0);

  // Calculate UltVeh and UltVehi.
  UltVeh = matrix_mult(U_l.T, V_e_h);
  UltVehi = matrix_mult(U_l.T, V_e_hi);

  return logdet_Ve;
}

// trace(PD) = trace((Hi-HixQixHi)D)=trace(HiD) - trace(HixQixHiD)
void Calc_tracePD(const DMatrix eval, const DMatrix Qi,
                  const DMatrix Hi, const DMatrix xHiDHix_all_g,
                  const DMatrix xHiDHix_all_e, const size_t i,
                  const size_t j, ref double tPD_g, ref double tPD_e) {
  writeln("in Calc_tracePD");

  size_t dc_size = Qi.shape[0], d_size = Hi.shape[0];
  size_t v = GetIndex(i, j, d_size);

  double d;

  // Calculate the first part: trace(HiD).
  Calc_traceHiD(eval, Hi, i, j, tPD_g, tPD_e);

  // Calculate the second part: -trace(HixQixHiD).
  for (size_t k = 0; k < dc_size; k++) {
    DMatrix Qi_row = get_row(Qi, k);
    DMatrix xHiDHix_g_col = get_col(xHiDHix_all_g, v * dc_size + k);
    DMatrix xHiDHix_e_col = get_col(xHiDHix_all_e, v * dc_size + k);

    d = vector_ddot(Qi_row, xHiDHix_g_col);
    tPD_g -= d;
    d = vector_ddot(Qi_row, xHiDHix_e_col);
    tPD_e -= d;
  }

  return;
}

// trace(PDPD) = trace((Hi-HixQixHi)D(Hi-HixQixHi)D)
//             = trace(HiDHiD) - trace(HixQixHiDHiD)
//               - trace(HiDHixQixHiD) + trace(HixQixHiDHixQixHiD)
void Calc_tracePDPD(const DMatrix eval, const DMatrix Qi,
                    const DMatrix Hi, const DMatrix xHi,
                    const DMatrix QixHiDHix_all_g,
                    const DMatrix QixHiDHix_all_e,
                    const DMatrix xHiDHiDHix_all_gg,
                    const DMatrix xHiDHiDHix_all_ee,
                    const DMatrix xHiDHiDHix_all_ge, const size_t i1,
                    const size_t j1, const size_t i2, const size_t j2,
                    ref double tPDPD_gg, ref double tPDPD_ee, ref double tPDPD_ge) {
  writeln("in Calc_tracePDPD");
  size_t dc_size = Qi.shape[0], d_size = Hi.shape[0];
  size_t v_size = d_size * (d_size + 1) / 2;
  size_t v1 = GetIndex(i1, j1, d_size), v2 = GetIndex(i2, j2, d_size);

  double d;

  // Calculate the first part: trace(HiDHiD).
  Calc_traceHiDHiD(eval, Hi, i1, j1, i2, j2, tPDPD_gg, tPDPD_ee, tPDPD_ge);

  // Calculate the second and third parts:
  // -trace(HixQixHiDHiD) - trace(HiDHixQixHiD)
  for (size_t i = 0; i < dc_size; i++) {
    DMatrix Qi_row = get_row(Qi, i);
    DMatrix xHiDHiDHix_gg_col = get_col(xHiDHiDHix_all_gg, (v1 * v_size + v2) * dc_size + i);
    DMatrix xHiDHiDHix_ee_col = get_col(xHiDHiDHix_all_ee, (v1 * v_size + v2) * dc_size + i);
    DMatrix xHiDHiDHix_ge_col = get_col(xHiDHiDHix_all_ge, (v1 * v_size + v2) * dc_size + i);

    d = vector_ddot(Qi_row, xHiDHiDHix_gg_col);
    tPDPD_gg -= d * 2.0;
    d = vector_ddot(Qi_row, xHiDHiDHix_ee_col);
    tPDPD_ee -= d * 2.0;
    d = vector_ddot(Qi_row, xHiDHiDHix_ge_col);
    tPDPD_ge -= d * 2.0;
  }

  // Calculate the fourth part: trace(HixQixHiDHixQixHiD).
  for (size_t i = 0; i < dc_size; i++) {

    DMatrix QixHiDHix_g_fullrow1 = get_row(QixHiDHix_all_g, i);
    DMatrix QixHiDHix_e_fullrow1 = get_row(QixHiDHix_all_e, i);
    DMatrix QixHiDHix_g_row1 = get_subvector_dmatrix(QixHiDHix_g_fullrow1, v1 * dc_size, dc_size);
    DMatrix QixHiDHix_e_row1 = get_subvector_dmatrix(QixHiDHix_e_fullrow1, v1 * dc_size, dc_size);

    DMatrix QixHiDHix_g_col2 = get_col(QixHiDHix_all_g, v2 * dc_size + i);
    DMatrix QixHiDHix_e_col2 = get_col(QixHiDHix_all_e, v2 * dc_size + i);

    d = vector_ddot(QixHiDHix_g_row1, QixHiDHix_g_col2);
    tPDPD_gg += d;
    d = vector_ddot(QixHiDHix_e_row1, QixHiDHix_e_col2);
    tPDPD_ee += d;
    d = vector_ddot(QixHiDHix_g_row1, QixHiDHix_e_col2);
    tPDPD_ge += d;
  }
  writeln("tPDPD_gg => ", tPDPD_gg);
  writeln("tPDPD_ee => ", tPDPD_ee);

  return;
}

void Calc_traceHiD(const DMatrix eval, const DMatrix Hi, const size_t i,
                   const size_t j, ref double tHiD_g, ref double tHiD_e) {
  tHiD_g = 0.0;
  tHiD_e = 0.0;

  size_t n_size = eval.size, d_size = Hi.shape[0];
  double delta, d;

  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];
    d = Hi.accessor(j, k * d_size + i);

    if (i == j) {
      tHiD_g += delta * d;
      tHiD_e += d;
    } else {
      tHiD_g += delta * d * 2.0;
      tHiD_e += d * 2.0;
    }
  }

  return;
}

void Calc_traceHiDHiD(const DMatrix eval, const DMatrix Hi,
                      const size_t i1, const size_t j1, const size_t i2,
                      const size_t j2, ref double tHiDHiD_gg, ref double tHiDHiD_ee,
                      ref double tHiDHiD_ge) {
  writeln("in Calc_traceHiDHiD");
  tHiDHiD_gg = 0.0;
  tHiDHiD_ee = 0.0;
  tHiDHiD_ge = 0.0;

  size_t n_size = eval.size, d_size = Hi.shape[0];
  double delta, d_Hi_i1i2, d_Hi_i1j2, d_Hi_j1i2, d_Hi_j1j2;

  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];

    d_Hi_i1i2 = Hi.accessor(i1, k * d_size + i2);
    d_Hi_i1j2 = Hi.accessor(i1, k * d_size + j2);
    d_Hi_j1i2 = Hi.accessor(j1, k * d_size + i2);
    d_Hi_j1j2 = Hi.accessor(j1, k * d_size + j2);

    if (i1 == j1) {
      tHiDHiD_gg += delta * delta * d_Hi_i1j2 * d_Hi_j1i2;
      tHiDHiD_ee += d_Hi_i1j2 * d_Hi_j1i2;
      tHiDHiD_ge += delta * d_Hi_i1j2 * d_Hi_j1i2;

      if (i2 != j2) {
        tHiDHiD_gg += delta * delta * d_Hi_i1i2 * d_Hi_j1j2;
        tHiDHiD_ee += d_Hi_i1i2 * d_Hi_j1j2;
        tHiDHiD_ge += delta * d_Hi_i1i2 * d_Hi_j1j2;
      }
    } else {
      tHiDHiD_gg +=
          delta * delta * (d_Hi_i1j2 * d_Hi_j1i2 + d_Hi_j1j2 * d_Hi_i1i2);
      tHiDHiD_ee += (d_Hi_i1j2 * d_Hi_j1i2 + d_Hi_j1j2 * d_Hi_i1i2);
      tHiDHiD_ge += delta * (d_Hi_i1j2 * d_Hi_j1i2 + d_Hi_j1j2 * d_Hi_i1i2);

      if (i2 != j2) {
        tHiDHiD_gg +=
            delta * delta * (d_Hi_i1i2 * d_Hi_j1j2 + d_Hi_j1i2 * d_Hi_i1j2);
        tHiDHiD_ee += (d_Hi_i1i2 * d_Hi_j1j2 + d_Hi_j1i2 * d_Hi_i1j2);
        tHiDHiD_ge += delta * (d_Hi_i1i2 * d_Hi_j1j2 + d_Hi_j1i2 * d_Hi_i1j2);
      }
    }
  }

  return;
}

void Calc_xHiDHiy(const DMatrix eval, const DMatrix xHi,
                  const DMatrix Hiy, const size_t i, const size_t j,
                  ref DMatrix xHiDHiy_g, ref DMatrix xHiDHiy_e) {
  writeln("in Calc_xHiDHiy");
  xHiDHiy_g = zeros_dmatrix(xHiDHiy_g.shape[0], xHiDHiy_g.shape[1]);
  xHiDHiy_e = zeros_dmatrix(xHiDHiy_e.shape[0], xHiDHiy_e.shape[1]);

  size_t n_size = eval.size, d_size = Hiy.shape[0];

  double delta, d;

  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];

    DMatrix xHi_col_i = get_col(xHi, k * d_size + i);
    d = Hiy.accessor(j, k);

    xHiDHiy_g = axpy(d * delta, xHi_col_i, xHiDHiy_g);  // daxpy
    xHiDHiy_e = axpy(d, xHi_col_i, xHiDHiy_e);  // daxpy

    if (i != j) {
      DMatrix xHi_col_j = get_col(xHi, k * d_size + j);
      d = Hiy.accessor(i, k);

      xHiDHiy_g = axpy(d, xHi_col_j, xHiDHiy_g);  // daxpy
      xHiDHiy_e = axpy(d, xHi_col_j, xHiDHiy_e); // daxpy
    }
  }

  return;
}

void Calc_xHiDHix(const DMatrix eval, const DMatrix xHi, const size_t i,
                  const size_t j, ref DMatrix xHiDHix_g, ref DMatrix xHiDHix_e) {
  //  VVI/TODO/CHECK
  writeln("In Calc_xHiDHix");
  xHiDHix_g = zeros_dmatrix(xHiDHix_g.shape[0], xHiDHix_g.shape[1]);
  xHiDHix_e = zeros_dmatrix(xHiDHix_e.shape[0], xHiDHix_e.shape[1]);

  size_t n_size = eval.size, dc_size = xHi.shape[0];
  size_t d_size = xHi.shape[1] / n_size;

  double delta;

  DMatrix mat_dcdc = zeros_dmatrix(dc_size, dc_size);
  DMatrix mat_dcdc_t = zeros_dmatrix(dc_size, dc_size);

  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];

    DMatrix xHi_col_i = get_col(xHi, k * d_size + i);
    DMatrix xHi_col_j = get_col(xHi, k * d_size + j);

    mat_dcdc = zeros_dmatrix(mat_dcdc.shape[0], mat_dcdc.shape[1]); //check
    mat_dcdc = ger(1.0, xHi_col_i, xHi_col_j, mat_dcdc);

    mat_dcdc_t = mat_dcdc.T;

    xHiDHix_e = add_dmatrix(xHiDHix_e, mat_dcdc);

    mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
    xHiDHix_g = add_dmatrix(xHiDHix_g, mat_dcdc);

    if (i != j) {
      xHiDHix_e = add_dmatrix(xHiDHix_e, mat_dcdc_t);

      mat_dcdc_t = multiply_dmatrix_num(mat_dcdc_t, delta);
      xHiDHix_g = add_dmatrix(xHiDHix_g, mat_dcdc_t);
    }
  }

  return;
}

void Calc_xHiDHiDHiy(const DMatrix eval, const DMatrix Hi,
                     const DMatrix xHi, const DMatrix Hiy,
                     const size_t i1, const size_t j1, const size_t i2,
                     const size_t j2, ref DMatrix xHiDHiDHiy_gg,
                     ref DMatrix xHiDHiDHiy_ee, ref DMatrix xHiDHiDHiy_ge) {
  writeln("in Calc_xHiDHiy");
  xHiDHiDHiy_gg = zeros_dmatrix(xHiDHiDHiy_gg.shape[0], xHiDHiDHiy_gg.shape[1]);
  xHiDHiDHiy_ee = zeros_dmatrix(xHiDHiDHiy_ee.shape[0], xHiDHiDHiy_ee.shape[1]);
  xHiDHiDHiy_ge = zeros_dmatrix(xHiDHiDHiy_ge.shape[0], xHiDHiDHiy_ge.shape[1]);

  size_t n_size = eval.size, d_size = Hiy.shape[0];

  double delta, d_Hiy_i, d_Hiy_j, d_Hi_i1i2, d_Hi_i1j2;
  double d_Hi_j1i2, d_Hi_j1j2;

  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];

    DMatrix xHi_col_i = get_col(xHi, k * d_size + i1);
    DMatrix xHi_col_j = get_col(xHi, k * d_size + j1);

    d_Hiy_i = Hiy.accessor(i2, k);
    d_Hiy_j = Hiy.accessor(j2, k);

    d_Hi_i1i2 = Hi.accessor(i1, k * d_size + i2);
    d_Hi_i1j2 = Hi.accessor(i1, k * d_size + j2);
    d_Hi_j1i2 = Hi.accessor(j1, k * d_size + i2);
    d_Hi_j1j2 = Hi.accessor(j1, k * d_size + j2);

    if (i1 == j1) {
      xHiDHiDHiy_gg = axpy(delta * delta * d_Hi_j1i2 * d_Hiy_j, xHi_col_i, xHiDHiDHiy_gg); // daxpy
      xHiDHiDHiy_ee = axpy(d_Hi_j1i2 * d_Hiy_j,                 xHi_col_i, xHiDHiDHiy_ee); // daxpy
      xHiDHiDHiy_ge = axpy(delta * d_Hi_j1i2 * d_Hiy_j,         xHi_col_i, xHiDHiDHiy_ge); // daxpy

      if (i2 != j2) {
        xHiDHiDHiy_gg = axpy(delta * delta * d_Hi_j1j2 * d_Hiy_i, xHi_col_i, xHiDHiDHiy_gg); // daxpy
        xHiDHiDHiy_ee = axpy(d_Hi_j1j2 * d_Hiy_i,                 xHi_col_i, xHiDHiDHiy_ee); // daxpy
        xHiDHiDHiy_ge = axpy(delta * d_Hi_j1j2 * d_Hiy_i,         xHi_col_i, xHiDHiDHiy_ge); // daxpy
      }
    } else {
      xHiDHiDHiy_gg = axpy(delta * delta * d_Hi_j1i2 * d_Hiy_j, xHi_col_i, xHiDHiDHiy_gg); // daxpy
      xHiDHiDHiy_ee = axpy(d_Hi_j1i2 * d_Hiy_j,                 xHi_col_i, xHiDHiDHiy_ee); // daxpy
      xHiDHiDHiy_ge = axpy(delta * d_Hi_j1i2 * d_Hiy_j,         xHi_col_i, xHiDHiDHiy_ge); // daxpy

      xHiDHiDHiy_gg = axpy(delta * delta * d_Hi_i1i2 * d_Hiy_j, xHi_col_j, xHiDHiDHiy_gg); // daxpy
      xHiDHiDHiy_ee = axpy(d_Hi_i1i2 * d_Hiy_j,                 xHi_col_j, xHiDHiDHiy_ee); // daxpy
      xHiDHiDHiy_ge = axpy(delta * d_Hi_i1i2 * d_Hiy_j,         xHi_col_j, xHiDHiDHiy_ge); // daxpy

      if (i2 != j2) {
        xHiDHiDHiy_gg = axpy(delta * delta * d_Hi_j1j2 * d_Hiy_i, xHi_col_i, xHiDHiDHiy_gg); // daxpy
        xHiDHiDHiy_ee = axpy(d_Hi_j1j2 * d_Hiy_i,                 xHi_col_i, xHiDHiDHiy_ee); // daxpy
        xHiDHiDHiy_ge = axpy(delta * d_Hi_j1j2 * d_Hiy_i,         xHi_col_i, xHiDHiDHiy_ge); // daxpy

        xHiDHiDHiy_gg = axpy(delta * delta * d_Hi_i1j2 * d_Hiy_i, xHi_col_j, xHiDHiDHiy_gg); // daxpy
        xHiDHiDHiy_ee = axpy(d_Hi_i1j2 * d_Hiy_i,                 xHi_col_j, xHiDHiDHiy_ee); // daxpy
        xHiDHiDHiy_ge = axpy(delta * d_Hi_i1j2 * d_Hiy_i,         xHi_col_j, xHiDHiDHiy_ge); // daxpy
      }
    }
  }

  return;
}

void Calc_xHiDHiDHix(const DMatrix eval, const DMatrix Hi,
                     const DMatrix xHi, const size_t i1, const size_t j1,
                     const size_t i2, const size_t j2,
                     ref DMatrix xHiDHiDHix_gg, ref DMatrix xHiDHiDHix_ee,
                     ref DMatrix xHiDHiDHix_ge) {
  writeln("in Calc_xHiDHiDHix");
  xHiDHiDHix_gg = zeros_dmatrix(xHiDHiDHix_gg.shape[0], xHiDHiDHix_gg.shape[1]);
  xHiDHiDHix_ee = zeros_dmatrix(xHiDHiDHix_ee.shape[0], xHiDHiDHix_ee.shape[1]);
  xHiDHiDHix_ge = zeros_dmatrix(xHiDHiDHix_ge.shape[0], xHiDHiDHix_ge.shape[1]);

  size_t n_size = eval.size, d_size = Hi.shape[0], dc_size = xHi.shape[0];

  double delta, d_Hi_i1i2, d_Hi_i1j2, d_Hi_j1i2, d_Hi_j1j2;

  DMatrix mat_dcdc = zeros_dmatrix(dc_size, dc_size);

  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];

    DMatrix xHi_col_i1 = get_col(xHi, k * d_size + i1);
    DMatrix xHi_col_j1 = get_col(xHi, k * d_size + j1);
    DMatrix xHi_col_i2 = get_col(xHi, k * d_size + i2);
    DMatrix xHi_col_j2 = get_col(xHi, k * d_size + j2);

    d_Hi_i1i2 = Hi.accessor(i1, k * d_size + i2);
    d_Hi_i1j2 = Hi.accessor(i1, k * d_size + j2);
    d_Hi_j1i2 = Hi.accessor(j1, k * d_size + i2);
    d_Hi_j1j2 = Hi.accessor(j1, k * d_size + j2);

    if (i1 == j1) {
      mat_dcdc = zeros_dmatrix(dc_size, dc_size);
      mat_dcdc = ger(d_Hi_j1i2, xHi_col_i1, xHi_col_j2, mat_dcdc);

      xHiDHiDHix_ee = add_dmatrix(xHiDHiDHix_ee, mat_dcdc);
      mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
      xHiDHiDHix_ge = add_dmatrix(xHiDHiDHix_ge, mat_dcdc);
      mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
      xHiDHiDHix_gg = add_dmatrix(xHiDHiDHix_gg, mat_dcdc);

      if (i2 != j2) {
        mat_dcdc = zeros_dmatrix(mat_dcdc.shape[0], mat_dcdc.shape[1]);
        mat_dcdc = ger(d_Hi_j1j2, xHi_col_i1, xHi_col_i2, mat_dcdc);

        xHiDHiDHix_ee = add_dmatrix(xHiDHiDHix_ee, mat_dcdc);
        mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
        xHiDHiDHix_ge = add_dmatrix(xHiDHiDHix_ge, mat_dcdc);
        mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
        xHiDHiDHix_gg = add_dmatrix(xHiDHiDHix_gg, mat_dcdc);
      }
    } else {
      mat_dcdc = zeros_dmatrix(dc_size, dc_size);  // check
      mat_dcdc = ger(d_Hi_j1i2, xHi_col_i1, xHi_col_j2, mat_dcdc);

      xHiDHiDHix_ee = add_dmatrix(xHiDHiDHix_ee, mat_dcdc);
      mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
      xHiDHiDHix_ge = add_dmatrix(xHiDHiDHix_ge, mat_dcdc);
      mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
      xHiDHiDHix_gg = add_dmatrix(xHiDHiDHix_gg, mat_dcdc);

      mat_dcdc = zeros_dmatrix(dc_size, dc_size); // check
      mat_dcdc = ger(d_Hi_i1i2, xHi_col_j1, xHi_col_j2, mat_dcdc);

      xHiDHiDHix_ee = add_dmatrix(xHiDHiDHix_ee, mat_dcdc);
      mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
      xHiDHiDHix_ge = add_dmatrix(xHiDHiDHix_ge, mat_dcdc);
      mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
      xHiDHiDHix_gg = add_dmatrix(xHiDHiDHix_gg, mat_dcdc);

      if (i2 != j2) {
        mat_dcdc = zeros_dmatrix(dc_size, dc_size);
        mat_dcdc = ger(d_Hi_j1j2, xHi_col_i1, xHi_col_i2, mat_dcdc);

        xHiDHiDHix_ee = add_dmatrix(xHiDHiDHix_ee, mat_dcdc);
        mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
        xHiDHiDHix_ge = add_dmatrix(xHiDHiDHix_ge, mat_dcdc);
        mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
        xHiDHiDHix_gg = add_dmatrix(xHiDHiDHix_gg, mat_dcdc);

        mat_dcdc = zeros_dmatrix(dc_size, dc_size);
        mat_dcdc = ger(d_Hi_i1j2, xHi_col_j1, xHi_col_i2, mat_dcdc);

        xHiDHiDHix_ee = add_dmatrix(xHiDHiDHix_ee, mat_dcdc);
        mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
        xHiDHiDHix_ge = add_dmatrix(xHiDHiDHix_ge, mat_dcdc);
        mat_dcdc = multiply_dmatrix_num(mat_dcdc, delta);
        xHiDHiDHix_gg = add_dmatrix(xHiDHiDHix_gg, mat_dcdc);
      }
    }
  }
  writeln("out");

  return;
}

void Calc_yHiDHiy(const DMatrix eval, const DMatrix Hiy, const size_t i,
                  const size_t j, ref double yHiDHiy_g, ref double yHiDHiy_e) {
  yHiDHiy_g = 0.0;
  yHiDHiy_e = 0.0;

  size_t n_size = eval.size;

  double delta, d1, d2;

  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];
    d1 = Hiy.accessor(i, k);
    d2 = Hiy.accessor(j, k);

    if (i == j) {
      yHiDHiy_g += delta * d1 * d2;
      yHiDHiy_e += d1 * d2;
    } else {
      yHiDHiy_g += delta * d1 * d2 * 2.0;
      yHiDHiy_e += d1 * d2 * 2.0;
    }
  }

  return;
}

void Calc_yHiDHiDHiy(const DMatrix eval, const DMatrix Hi,
                     const DMatrix Hiy, const size_t i1, const size_t j1,
                     const size_t i2, const size_t j2, ref double yHiDHiDHiy_gg,
                     ref double yHiDHiDHiy_ee, ref double yHiDHiDHiy_ge) {
  yHiDHiDHiy_gg = 0.0;
  yHiDHiDHiy_ee = 0.0;
  yHiDHiDHiy_ge = 0.0;

  size_t n_size = eval.size, d_size = Hiy.shape[0];

  double delta, d_Hiy_i1, d_Hiy_j1, d_Hiy_i2, d_Hiy_j2;
  double d_Hi_i1i2, d_Hi_i1j2, d_Hi_j1i2, d_Hi_j1j2;

  for (size_t k = 0; k < n_size; k++) {
    delta = eval.elements[k];

    d_Hiy_i1 = Hiy.accessor(i1, k);
    d_Hiy_j1 = Hiy.accessor(j1, k);
    d_Hiy_i2 = Hiy.accessor(i2, k);
    d_Hiy_j2 = Hiy.accessor(j2, k);

    d_Hi_i1i2 = Hi.accessor(i1, k * d_size + i2);
    d_Hi_i1j2 = Hi.accessor(i1, k * d_size + j2);
    d_Hi_j1i2 = Hi.accessor(j1, k * d_size + i2);
    d_Hi_j1j2 = Hi.accessor(j1, k * d_size + j2);

    if (i1 == j1) {
      yHiDHiDHiy_gg += delta * delta * (d_Hiy_i1 * d_Hi_j1i2 * d_Hiy_j2);
      yHiDHiDHiy_ee += (d_Hiy_i1 * d_Hi_j1i2 * d_Hiy_j2);
      yHiDHiDHiy_ge += delta * (d_Hiy_i1 * d_Hi_j1i2 * d_Hiy_j2);

      if (i2 != j2) {
        yHiDHiDHiy_gg += delta * delta * (d_Hiy_i1 * d_Hi_j1j2 * d_Hiy_i2);
        yHiDHiDHiy_ee += (d_Hiy_i1 * d_Hi_j1j2 * d_Hiy_i2);
        yHiDHiDHiy_ge += delta * (d_Hiy_i1 * d_Hi_j1j2 * d_Hiy_i2);
      }
    } else {
      yHiDHiDHiy_gg += delta * delta * (d_Hiy_i1 * d_Hi_j1i2 * d_Hiy_j2 +
                                        d_Hiy_j1 * d_Hi_i1i2 * d_Hiy_j2);
      yHiDHiDHiy_ee +=
          (d_Hiy_i1 * d_Hi_j1i2 * d_Hiy_j2 + d_Hiy_j1 * d_Hi_i1i2 * d_Hiy_j2);
      yHiDHiDHiy_ge += delta * (d_Hiy_i1 * d_Hi_j1i2 * d_Hiy_j2 +
                                d_Hiy_j1 * d_Hi_i1i2 * d_Hiy_j2);

      if (i2 != j2) {
        yHiDHiDHiy_gg += delta * delta * (d_Hiy_i1 * d_Hi_j1j2 * d_Hiy_i2 +
                                          d_Hiy_j1 * d_Hi_i1j2 * d_Hiy_i2);
        yHiDHiDHiy_ee +=
            (d_Hiy_i1 * d_Hi_j1j2 * d_Hiy_i2 + d_Hiy_j1 * d_Hi_i1j2 * d_Hiy_i2);
        yHiDHiDHiy_ge += delta * (d_Hiy_i1 * d_Hi_j1j2 * d_Hiy_i2 +
                                  d_Hiy_j1 * d_Hi_i1j2 * d_Hiy_i2);
      }
    }
  }

  return;
}

// Does NOT set eigenvalues to be positive. G gets destroyed. Returns
// eigen trace and values in U and eval (eigenvalues).
double EigenDecomp(DMatrix G, ref DMatrix U, ref DMatrix eval,
                   const size_t flag_largematrix) {
  //writeln("in EigenDecomp");
  lapack_eigen_symmv(G, eval, U, flag_largematrix);
  // Calculate track_G=mean(diag(G)).
  double d = 0.0;
  for (size_t i = 0; i < eval.size; ++i){
    d += eval.elements[i];
  }

  d /= to!double(eval.size);
  return d;
}

// Same as EigenDecomp but zeroes eigenvalues close to zero. When
// negative eigenvalues remain a warning is issued.
double EigenDecomp_Zeroed(DMatrix G, ref DMatrix U, ref DMatrix eval,
                          const size_t flag_largematrix) {
  //writeln("in EigenDecomp_Zeroed");
  EigenDecomp(G,U,eval,flag_largematrix);
  //writeln("eval = ", eval);
  auto d = 0.0;
  int count_zero_eigenvalues = 0;
  int count_negative_eigenvalues = 0;
  for (size_t i = 0; i < eval.size; i++) {
    if (abs(eval.elements[i]) < EIGEN_MINVALUE)
      eval.elements[i] = 0.0;
    // checks
    if (eval.elements[i] == 0.0)
      count_zero_eigenvalues += 1;
    if (eval.elements[i]  < 0.0) // count smaller than -EIGEN_MINVALUE
      count_negative_eigenvalues += 1;
    d += eval.elements[i] ;
  }
  d /= to!double(eval.size);
  if (count_zero_eigenvalues > 1) {
    writeln("Matrix G has ", count_zero_eigenvalues, " eigenvalues close to zero");
  }
  if (count_negative_eigenvalues > 0) {
    writeln("Matrix G has more than one negative eigenvalues!");
  }

  return d;
}


unittest{
  DMatrix G = DMatrix([5, 5], [ 12, -3,  5, 92, 91,
                                71, 65, 51, 77, 17,
                               -62, -4, 26, 16,-10,
                                27, 13, 69, 46, 27,
                                39, 47, 11, 68, 62 ]);
  DMatrix U = zeros_dmatrix(5, 5);
  DMatrix eval = zeros_dmatrix(5, 1);
  size_t flag_largematrix = 0;
  EigenDecomp(G, U, eval, flag_largematrix);

  assert(eqeq(U, DMatrix([5, 5], [-0.701244, -0.351106,  0.120902,  0.358052, 0.492101,
                                  -0.322078,  0.567296, -0.114051, -0.618097, 0.423544,
                                   0.115668, -0.664204, -0.557493, -0.457066, 0.160457,
                                   0.524497, -0.165452,  0.582959, -0.133196, 0.583050,
                                   0.340657,  0.293869, -0.567218,  0.512936, 0.461252])
         ));
  assert(eqeq(eval, DMatrix([5, 1], [-103.221, -6.50605, 8.44382, 106.936, 205.347])));

  flag_largematrix = 1;
  EigenDecomp(G, U, eval, flag_largematrix);


  assert(eqeq(U, DMatrix([5, 5], [ 0.701244, -0.351106, 0.120902, 0.358052, -0.492101,
                                   0.322078, 0.567296, -0.114051, -0.618097, -0.423544,
                                  -0.115668, -0.664204, -0.557493, -0.457066, -0.160457,
                                  -0.524497, -0.165452, 0.582959, -0.133196, -0.58305,
                                  -0.340657, 0.293869, -0.567218, 0.512936, -0.461252])

         ));
  assert(eqeq(eval, DMatrix([5, 1], [-103.221, -6.50605, 8.44382, 106.936, 205.347])));
}

unittest{
  writeln("EigenDecomp_Zeroed Test");
  DMatrix G = DMatrix([5, 5], [ 12, -3,  5, 92, 91,
                                71, 65, 51, 77, 17,
                               -62, -4, 26, 16,-10,
                                27, 13, 69, 46, 27,
                                39, 47, 11, 68, 62 ]);
  DMatrix U = zeros_dmatrix(5,5);
  DMatrix eval = zeros_dmatrix(5, 1);
  size_t flag_largematrix = 0;

  double zeroed = EigenDecomp_Zeroed(G, U, eval, flag_largematrix);
  assert(eqeq(U, DMatrix([5, 5], [-0.701244, -0.351106,  0.120902,  0.358052, 0.492101,
                                  -0.322078,  0.567296, -0.114051, -0.618097, 0.423544,
                                   0.115668, -0.664204, -0.557493, -0.457066, 0.160457,
                                   0.524497, -0.165452,  0.582959, -0.133196, 0.583050,
                                   0.340657,  0.293869, -0.567218,  0.512936, 0.461252])
         ));
  assert(eqeq(eval, DMatrix([5, 1], [-103.221, -6.50605, 8.44382, 106.936, 205.347])));

  flag_largematrix = 1;
  EigenDecomp(G, U, eval, flag_largematrix);


  assert(eqeq(U, DMatrix([5, 5], [ 0.701244, -0.351106, 0.120902, 0.358052, -0.492101,
                                   0.322078, 0.567296, -0.114051, -0.618097, -0.423544,
                                  -0.115668, -0.664204, -0.557493, -0.457066, -0.160457,
                                  -0.524497, -0.165452, 0.582959, -0.133196, -0.58305,
                                  -0.340657, 0.293869, -0.567218, 0.512936, -0.461252])

         ));
  assert(eqeq(eval, DMatrix([5, 1], [-103.221, -6.50605, 8.44382, 106.936, 205.347])));
}

unittest{

  writeln("EigenProc Test");

  DMatrix V_g = DMatrix([5, 5], [ 14, -3,  5, 92, 91,
                                  71, 65, 53, 77, 17,
                                 -62,  4, 26, 16,-10,
                                  27, 43, -9, 46, 27,
                                  39, 47, 11, 78, 62 ]);
  DMatrix V_e = DMatrix([5, 5], [ 12, -3,  5, 92, 11,
                                  71, 65, 51, 77, 17,
                                 -62, -4, 26, 16, 25,
                                  27, 13, 69, 46, 27,
                                  19, 27, 11, 68, 62 ]);
  DMatrix D_l = zeros_dmatrix(5, 1);
  DMatrix UltVeh = zeros_dmatrix(5, 5);
  DMatrix UltVehi = zeros_dmatrix(5, 5);
  double val = EigenProc(V_g, V_e, D_l, UltVeh, UltVehi);

  assert(abs(val - 13.3488) < 1e-03);

  assert(eqeq(D_l, DMatrix([5, 1], [-0.298469, -0.0580587, 0.0970617, 0.756929, 1.7259])));

  assert(eqeq(UltVeh, DMatrix([5, 5], [ 3.69273, -1.67618, -3.25889, 2.7771, -4.98979,
                                        1.21751, 1.11122, 0.0471454, 1.73204, -0.952682,
                                        0.317094, -0.257066, -0.378097, 0.180578, -0.560401,
                                       -3.22554, -8.55505, -4.5197, -7.40815, -2.17346,
                                       4.6262, -1.21874, -0.505007, 4.23425, 5.62528])
        ));
  assert(eqeq(UltVehi, DMatrix([5, 5], [0.0554459, -0.0171301, -0.0473149, 0.0452304, -0.0862392,
                                        0.0113779, 0.00939418, -0.00426404, 0.0152636, -0.024888,
                                        0.00530134, -0.00216299, -0.00504649, 0.0040487, -0.00911448,
                                        -0.00489163, -0.0664068, -0.0328564, -0.0363691, 0.0131071,
                                        0.0561932, -0.0583603, -0.0244037, 0.0312601, 0.0929895])
        ));
}


unittest{

  writeln("CalcQi Test");

  DMatrix eval = DMatrix([3,1], [17, 11, 102]);
  DMatrix D_l = DMatrix([3,1], [24, 120, 5]);
  DMatrix X = DMatrix([3, 3], [11, 23, 45
                              ,44, 21, 65
                              ,51, 29, 46]);
  DMatrix Qi = zeros_dmatrix(3,3);

  double qi = CalcQi(eval, D_l, X, Qi);
  assert(abs(qi - 3.36348) < 1e-03);
  assert(eqeq(Qi, DMatrix([3, 3], [ 0.320622, 0,       0,
                                    0,        1.59957, 0,
                                    0,        0,       0.0674936])

        ));
}

unittest{

  size_t em_iter = 10; //check
  double em_prec = 0;
  size_t nr_iter = 0;
  double nr_prec = 0;
  double l_min = 1e-05;
  double l_max = 100000;
  size_t n_region = 10;
  DMatrix X = DMatrix([5, 5], [ 14, -3,  5, 92, 91,
                                71, 65, 53, 77, 17,
                               -62,  4, 26, 16,-10,
                                27, 43, -9, 46, 27,
                                39, 47, 11, 78, 62 ]);
  DMatrix Y = DMatrix([3,5], [7, 12, 1, -9 , 6,
                               17, 212, 11, -14 , 61,
                               33, 42, 10, -09 , 6]);

  DMatrix eval = DMatrix([5,1], [7, 12, 1, -9 , 6]);

  DMatrix V_g = zeros_dmatrix(5, 5);
  DMatrix V_e = zeros_dmatrix(5, 5);
  DMatrix B = zeros_dmatrix(5, 5);

  //MphInitial(em_iter, em_prec, nr_iter, nr_prec, eval, X, Y, l_min, l_max, n_region, V_g, V_e, B);
  //write("V_g = ", V_g);
  //assert(V_g == DMatrix([], []));
  //assert(V_e == DMatrix([], []));
  //assert(B == DMatrix([], []));

}

unittest{
  writeln("CalcXHiY test"); //   pass

  DMatrix eval = DMatrix([3,1], [17, 11, 102]);
  DMatrix D_l = DMatrix([3,1], [24, 120, 5]);
  DMatrix X = DMatrix([3, 3], [11, 23, 45
                              ,44, 21, 65
                              ,51, 29, 46]);
  DMatrix UltVehiY = DMatrix([3, 3], [11, 23, 45
                                     ,44, 21, 65
                                     ,51, 29, 46]);
  DMatrix xHiy = zeros_dmatrix(9,1);

  CalcXHiY(eval, D_l, X, UltVehiY, xHiy);
  assert(eqeq(xHiy, DMatrix([9, 1], [ 3.11894, 0.841722, 22.4849,
                                      4.20038, 1.62754,  42.8193,
                                      4.73386, 1.80474, 49.4029])));
}

unittest{
  writeln("CalcOmega test"); // pass
  DMatrix eval = DMatrix([3,1], [17, 11, 102]);
  DMatrix D_l = DMatrix([3,1], [24, 120, 5]);
  DMatrix OmegaU = zeros_dmatrix(3,3);
  DMatrix OmegaE = zeros_dmatrix(3,3);

  CalcOmega(eval, D_l, OmegaU,  OmegaE);
  assert(eqeq(OmegaU, DMatrix([3, 3], [ 0.0586797, 0.090566,  0.00979992,
                                        0.0587947, 0.0908403, 0.00980312,
                                        0.0581395, 0.0892857, 0.00978474])
        ));
  assert(eqeq(OmegaE, DMatrix([3, 3], [ 0.997555, 0.996226, 0.999592,
                                        0.99951,  0.999243, 0.999918,
                                        0.988372, 0.982143, 0.998043])
        ));
}

unittest{
  writeln("UpdateRL_B Test");  // pass
  DMatrix xHiy = DMatrix([4,1], [ 11, 23, 45, 44]);
  DMatrix Qi = DMatrix([4, 4], [ 0.320622, 0,       0,         0,
                                 0,        1.59957, 0,         0,
                                 0,        0,       0.0674936, 0,
                                 0,        0,       0,         0.174226]);
  DMatrix UltVehiB = zeros_dmatrix(2,1);
  UpdateRL_B(xHiy, Qi, UltVehiB);
  writeln(UltVehiB);
  assert(eqeq(UltVehiB, DMatrix([2, 1], [3.52684, 36.7901])
        ));
}

unittest{

  writeln("UpdateU Test");      // pass
  DMatrix UltVehiY  = DMatrix([2,2] , [11, 23, 645, -10]);
  DMatrix UltVehiBX = DMatrix([2,2] , [99, -23, 72, 20]);
  DMatrix OmegaE    = DMatrix([2,2] , [-11, 8, 99, 21]);
  DMatrix UltVehiU  = zeros_dmatrix(2,2);

  UpdateU(OmegaE, UltVehiY, UltVehiBX, UltVehiU);
  assert(UltVehiU == DMatrix([2, 2], [968, 368, 56727, -630]));
}

unittest{
  writeln("UpdateL_B Test");      // pass
  DMatrix X         = DMatrix([2,2] , [ 1,  3, 15,  20]);
  DMatrix XXti      = DMatrix([2,2] , [22, 13, 50,   7]);
  DMatrix UltVehiY  = DMatrix([2,2] , [11, 23, 85, -10]);
  DMatrix UltVehiU  = DMatrix([2,2] , [968, 368, 56727, -630]);
  DMatrix UltVehiBX = zeros_dmatrix(2, 2);
  DMatrix UltVehiB  = zeros_dmatrix(2, 2);

  UpdateL_B(X, XXti, UltVehiY, UltVehiU, UltVehiBX, UltVehiB);
  assert(UltVehiBX  == DMatrix([2, 2], [-957, -345, -56642, 620]));
  writeln(eqeq(UltVehiB , DMatrix([2,2], [-1.10657e+06, -174681,
                                          -4.30667e+07, -6.57278e+06])
          ));
}

unittest{
  writeln("UpdateE Test");  // pass
  DMatrix UltVehiY = DMatrix([2,2] , [11, 23, 85, -10]);
  DMatrix UltVehiBX = DMatrix([2, 2], [-957, -345, -56642, 620]);
  DMatrix UltVehiU =  DMatrix([2,2] , [968, 36, 727, -630]);
  DMatrix UltVehiE = zeros_dmatrix(2,2);

  UpdateE(UltVehiY, UltVehiBX, UltVehiU, UltVehiE);
  assert(UltVehiE == DMatrix([2, 2], [0, 332, 56000, 0]));
}


unittest{

  writeln("CalcSigma Test"); //pass
  char func_name = 'L';
  DMatrix eval = DMatrix([3,1], [17, 11, 102]);
  DMatrix D_l = DMatrix([3,1], [24, 120, 5]);
  DMatrix X = DMatrix([3, 3], [ 11, 23, 45,
                                44, 21, 65,
                                51, 29, 46]);
  DMatrix UltVeh = DMatrix([3, 3], [ 18,  7,  45,
                                     44, 101,  5,
                                     51,  29, 26]);
  DMatrix OmegaU = DMatrix([3, 3], [ 0.0586797, 0.090566,  0.00979992,
                                     0.0587947, 0.0908403, 0.00980312,
                                     0.0581395, 0.0892857, 0.00978474 ]);
  DMatrix OmegaE = DMatrix([3, 3], [ 0.997555, 0.996226, 0.999592,
                                     0.99951,  0.999243, 0.999918,
                                     0.988372, 0.982143, 0.998043 ]);

  DMatrix Qi = DMatrix([3, 3], [ 0.320622, 0,       0,
                                 0,        1.59957, 0,
                                 0,        0,       0.0674936]);
  DMatrix Sigma_uu = zeros_dmatrix(3,3);
  DMatrix Sigma_ee = zeros_dmatrix(3,3);

  CalcSigma(func_name, eval, D_l,  X, OmegaU,  OmegaE, UltVeh, Qi, Sigma_uu, Sigma_ee);
  assert(eqeq(Sigma_uu, DMatrix([3, 3], [ 769.106,  961.096, 372.364,
                                          961.096, 1766.436, 249.152,
                                          372.364,  249.152, 432.327])
        ));
  assert(eqeq(Sigma_ee, DMatrix([3, 3], [ 14496.5,   18093.757, 7020.648,
                                          18093.757, 33232.676, 4695.534,
                                          7020.648,  4695.534,  8143.292])
        ));
}

unittest{

  writeln("UpdateV Test");          //pass
  DMatrix eval = DMatrix([3,1], [17, 11, 102]);
  DMatrix U = DMatrix([3,3], [ 3,  1, 13,
                               4,  5, 70,
                              12, 46,-22]);
  DMatrix E = DMatrix([3,3], [ 8, 21, 56,
                              12, 46,-22,
                              24, 91, 170]);
  DMatrix Sigma_uu = DMatrix([3,3], [15, 25, 8, 15, 25, 8, 15, 25, 8]);
  DMatrix Sigma_ee = DMatrix([3,3], [ 5, 12,61, 15, 25, 8, 61, 15, 25]);
  DMatrix V_g = zeros_dmatrix(3,3);
  DMatrix V_e = zeros_dmatrix(3,3);

  UpdateV(eval, U, E, Sigma_uu, Sigma_ee, V_g, V_e);
  writeln("V_e = ", V_e);
  assert(eqeq(V_g, DMatrix([3, 3], [5.75906, 11.694,  3.83185,
                                    8.36067, 25.4177, 5.54486,
                                    6.16518, 11.2115, 71.1931])
         ));
  assert(eqeq(V_e, DMatrix([3, 3], [1215.333,  -52.6667, 3894.667,
                                     -51.6667, 923,       247.333,
                                    3894.667,  249.667, 12594])
         ));

}

unittest{
  writeln("MphCalcLogL Test"); // pass
  DMatrix eval = DMatrix([3,1], [17, 11, 102]);
  DMatrix D_l = DMatrix([3,1], [24, 120, 5]);
  DMatrix xHiy = DMatrix([3,1], [2, 10, 15]);
  DMatrix UltVehiY = DMatrix([3, 3], [11, 23, 45
                                     ,44, 21, 65
                                     ,51, 29, 46]);
  DMatrix Qi = DMatrix([3, 3], [ 0.320622, 0,       0,
                                 0,        1.59957, 0,
                                 0,        0,       0.0674936]);
  double logl = MphCalcLogL(eval, xHiy, D_l, UltVehiY, Qi);
  writeln("logl =>", logl);
  assert(abs(logl - 31.9716) <= 1e-03);

}

unittest{

  char func_name = 'L';
  size_t max_iter = 10000;
  double max_prec = 0.0001;
  DMatrix eval = DMatrix([3,1], [17, 11, 102]);
  DMatrix X = DMatrix([3, 3], [ 11, 23, 45,
                                44, 21, 65,
                                51, 29, 46]);

  DMatrix Y  = DMatrix([3, 3], [11, 1, 23
                               ,44, 91,21
                               ,51, 2,  9]);
  DMatrix U_hat =  DMatrix([3, 2], [11, 23
                               ,44, 21
                               ,51, 29]);
  DMatrix E_hat =  DMatrix([3, 2], [11, 23
                               ,44, 21
                               ,51, 29]);
  DMatrix OmegaU = DMatrix([3, 3], [ 0.0586797, 0.090566,  0.00979992,
                                     0.0587947, 0.0908403, 0.00980312,
                                     0.0581395, 0.0892857, 0.00978474 ]);
  DMatrix OmegaE = DMatrix([3, 3], [ 0.997555, 0.996226, 0.999592,
                                     0.99951,  0.999243, 0.999918,
                                     0.988372, 0.982143, 0.998043 ]);
  DMatrix UltVehiY = DMatrix([3, 6], [11, 23, 45
                                     ,44, 91,  6
                                     ,19, 33, 25
                                     ,24, 31, 35
                                     , 1, 23, 97
                                     ,51, -9, 46]);
  DMatrix UltVehiBX = DMatrix([3, 3] , [99, -23, 23,
                                        45,  94, 21,
                                        12,  20, 87]);
  DMatrix UltVehiU = DMatrix([3, 3] , [ 19,   3, 213,
                                        88, -17, 201,
                                        98,  12, 87]);
  DMatrix UltVehiE= DMatrix([3, 3] , [ 29,  13, -3,
                                        18, 7, 1,
                                        98,  2, 8]);
  DMatrix V_g = DMatrix([3, 3], [5.75906, 11.694,  3.83185,
                                    8.36067, 25.4177, 5.54486,
                                    6.16518, 11.2115, 71.1931]);
  DMatrix V_e    = DMatrix([3, 3], [1215.333,  -52.6667, 3894.667,
                                     -51.6667, 923,      1247.333,
                                    3894.667,  249.667, 12594]);
  DMatrix B  = DMatrix([3, 3], [89, 32, 14
                                     ,66, 92, 625
                                     ,50, -29, 18]);

  //MphEM(func_name, max_iter, max_prec, eval, X, Y, U_hat, E_hat, OmegaU,
  //OmegaE, UltVehiY, UltVehiBX, UltVehiU,  UltVehiE, V_g, V_e, B);
  //assert(U_hat);
  //assert(E_hat);
  //assert(OmegaU);
  //assert(OmegaE);
  //assert(UltVehiY);
  //assert(UltVehiBX);
  //assert(UltVehiU);
  //assert(UltVehiE);
  //assert(V_g);
  //assert(V_e);
  //assert(B);

}

unittest{

  DMatrix Hessian_inv = DMatrix([12, 3], [ 4, 17, 111,
                                          12, 21, 12,
                                          76, 12, 124,
                                          41, 17, 11,
                                          12, 11, 102,
                                          76, 12, 24,
                                          14, 72, 18,
                                          12, 11, 12,
                                          16, 12, 19,
                                          4,   7, 10,
                                          23, 21, 12,
                                          76, 12, 24 ]);
  size_t v_size = 3 * (3 + 1) / 2;
  DMatrix gradient = zeros_dmatrix(v_size*2, 1);
  double step_scale = 0.2;
  DMatrix V_g = DMatrix([3,3], [12, 13, 556,
                                81,  8,  99,
                               -11, 12,  06]);
  DMatrix V_e = DMatrix([3,3], [15,  1, -26,
                                71, -8,   9,
                              -101, 33,   6]);

  UpdateVgVe(Hessian_inv, gradient, step_scale, V_g, V_e);
  writeln("V_g => ", V_g);
  //assert(eqeq(V_g, DMatrix([], [])));
  //assert(V_e);

}

unittest{

  char func_name;
  size_t max_iter;
  double max_prec;
  DMatrix eval;
  DMatrix X;
  DMatrix Y;
  DMatrix Hi_all;
  DMatrix xHi_all;
  DMatrix Hiy_all;
  DMatrix V_g;
  DMatrix V_e;
  DMatrix Hessian_inv;
  double crt_a;
  double crt_b;
  double crt_c;

  //double mphnr = MphNR(func_name, max_iter, max_prec, eval, X, Y, Hi_all,  xHi_all, Hiy_all, V_g, V_e, Hessian_inv, crt_a, crt_b, crt_c);
  //assert(Hi_all);
  //assert(xHi_all);
  //assert(Hiy_all);
  //assert(V_g);
  //assert(V_e);
  //assert(Hessian_inv);
  //assert(crt_a);
  //assert(crt_b);
  //assert(crt_c);
  //assert(mphnr);

}

unittest{

  DMatrix eval;
  DMatrix x_vec;
  DMatrix W;
  DMatrix Y;
  DMatrix V_g;
  DMatrix V_e;
  DMatrix UltVehiY;
  DMatrix beta;
  DMatrix Vbeta;

  //double mph_p = MphCalcP(eval, x_vec, W, Y, V_g, V_e, UltVehiY, beta,  Vbeta);
  //assert(UltVehiY);
  //assert(beta);
  //assert(Vbeta);
  //assert(mph_p);

}

unittest{

  DMatrix eval;
  DMatrix W;
  DMatrix Y;
  DMatrix V_g;
  DMatrix V_e;
  DMatrix UltVehiY;
  DMatrix B;
  DMatrix se_B;


  //MphCalcBeta(eval, W, Y, V_g, V_e, UltVehiY, B, se_B);
  //assert(UltVehiY);
  //assert(B);
  //assert(se_B);

}

unittest{

  char func_name = 'L';
  DMatrix eval = DMatrix([3,1], [17, 11, 102]);
  DMatrix Qi =  zeros_dmatrix(3,3);
  DMatrix Hi = zeros_dmatrix(3,1);
  DMatrix xHi = zeros_dmatrix(3,1);
  DMatrix Hiy = zeros_dmatrix(3,1);
  DMatrix QixHiy = zeros_dmatrix(3,1);
  DMatrix gradient = zeros_dmatrix(3,1);
  DMatrix Hessian_inv = zeros_dmatrix(3,3);
  double crt_a = 0;
  double crt_b = 0;
  double crt_c = 0;

  //CalcDev(func_name, eval, Qi, Hi, xHi, Hiy, QixHiy, gradient, Hessian_inv, crt_a, crt_b, crt_c);

  func_name = 'R';

  //assert(gradient = DMatrix([], []));
  //assert(Hessian_inv = DMatrix([], [])),
  //assert(crt_a == 0);
  //assert(crt_b == 0);
  //assert(crt_c == 0);
}

unittest{
  //[427, 1] [8, 1708] [4, 427] [8, 10] [8, 10]
  DMatrix eval = DMatrix([2,1], [102, -19]);
  DMatrix x = DMatrix([8, 1], [71, 3, 75, 12, -22, 234, 67, 12]);
  DMatrix Hi = DMatrix([1, 8], [32, 5, 12, -2, 71, 4, 88, -21]);
  DMatrix xHi = matrix_mult(x, Hi);
  DMatrix Hiy = ones_dmatrix(4,  2);

  size_t i = 0;
  size_t j = 0;
  DMatrix xHiDHiy_all_g = ones_dmatrix(8,10);
  DMatrix xHiDHiy_all_e = ones_dmatrix(8,10);

  Calc_xHiDHiy_all(eval, xHi, Hiy, xHiDHiy_all_g, xHiDHiy_all_e);
  writeln("xHiDHiy_all_g => ", xHiDHiy_all_g);
  writeln("xHiDHiy_all_e => ", xHiDHiy_all_e);
  assert(xHiDHiy_all_g == DMatrix([8, 10], [135965,  136604,  143065, 134332,  30814,  37914,  29181, -31808,
                                            -33441,   13845,    5745,   5772,   6045,   5676,   1302,   1602,
                                              1233,   -1344,   -1413,    585, 143625, 144300, 151125, 141900,
                                             32550,   40050,   30825, -33600, -35325,  14625,  22980,  23088,
                                             24180,   22704,    5208,   6408,   4932,  -5376,  -5652,   2340,
                                            -42130,  -42328,  -44330, -41624,  -9548, -11748,  -9042,   9856,
                                             10362,   -4290,  448110, 450216, 471510, 442728, 101556, 124956,
                                             96174, -104832, -110214,  45630, 128305, 128908, 135005, 126764,
                                             29078,   35778,   27537, -30016, -31557,  13065,  22980,  23088,
                                             24180,   22704,    5208,   6408,   4932,  -5376,  -5652,   2340]));
  assert(xHiDHiy_all_e == DMatrix([8, 10], [7313,  7952, 14413,  5680,   639,  7739,  -994,  7100,
                                            5467, -1633,   309,   336,   609,   240,    27,   327,
                                             -42,   300,   231,   -69,  7725,  8400, 15225,  6000,
                                             675,  8175, -1050,  7500,  5775, -1725,  1236,  1344,
                                            2436,   960,   108,  1308,  -168,  1200,   924,  -276,
                                           -2266, -2464, -4466, -1760,  -198, -2398,   308, -2200,
                                           -1694,   506, 24102, 26208, 47502, 18720,  2106, 25506,
                                           -3276, 23400, 18018, -5382,  6901,  7504, 13601,  5360,
                                             603,  7303,  -938,  6700,  5159, -1541,  1236,  1344,
                                            2436,   960,   108,  1308,  -168,  1200,   924,  -276]));
}

unittest{

  DMatrix eval = DMatrix([3,1], [17, 11, 102]);
  DMatrix xHi = zeros_dmatrix(3,1);
  DMatrix xHiDHix_all_g = zeros_dmatrix(3,1);
  DMatrix xHiDHix_all_e = zeros_dmatrix(3,1);

  Calc_xHiDHix_all(eval, xHi, xHiDHix_all_g, xHiDHix_all_e);
  //assert(xHiDHix_all_g);
  //assert(xHiDHix_all_e);
}
//
unittest{

  size_t v_size = 10;

  DMatrix eval = DMatrix([2,1], [102, -19]);
  DMatrix x = DMatrix([8, 1], [71, 3, 75, 12, -22, 234, 67, 12]);
  DMatrix Hi = DMatrix([1, 8], [32, 5, 12, -2, 71, 4, 88, -21]);
  DMatrix xHi = matrix_mult(x, Hi);
  DMatrix Hiy = ones_dmatrix(4,  2);

  DMatrix xHiDHiDHiy_all_gg = zeros_dmatrix(8, 100);
  DMatrix xHiDHiDHiy_all_ee = zeros_dmatrix(8, 100);
  DMatrix xHiDHiDHiy_all_ge = zeros_dmatrix(8, 100);

  // TODO
  //Calc_xHiDHiDHiy_all(v_size, eval, Hi, xHi, Hiy, xHiDHiDHiy_all_gg, xHiDHiDHiy_all_ee, xHiDHiDHiy_all_ge);
  //writeln("xHiDHiDHiy_all_gg => ", xHiDHiDHiy_all_gg);
  //writeln("xHiDHiDHiy_all_ee => ", xHiDHiDHiy_all_ee);
  //writeln("xHiDHiDHiy_all_ge => ", xHiDHiDHiy_all_ge);

  //assert(xHiDHiDHiy_all_gg == DMatrix([], []));
  //assert(xHiDHiDHiy_all_ee == DMatrix([], []));
  //assert(xHiDHiDHiy_all_ge == DMatrix([], []));
}

unittest{

  size_t v_size = 10;
  DMatrix eval = DMatrix([2,1], [102, -19]);
  DMatrix x = DMatrix([8, 2], [71, 3, 75, 12, -22, 234, 67, 12,
                               11, 32, 7, 22,  -2,  -5, 12, 10]);
  DMatrix Hi = DMatrix([2, 8], [32, 5, 12, -2, 71, 4, 88, -21,
                                11, 32, 7, 22,  -2,  -5, 12, 10]);
  DMatrix xHi = matrix_mult(x, Hi);

  DMatrix xHiDHiDHix_all_gg = zeros_dmatrix(100, 8);
  DMatrix xHiDHiDHix_all_ee = zeros_dmatrix(100, 8);
  DMatrix xHiDHiDHix_all_ge = zeros_dmatrix(100, 8);

  //Calc_xHiDHiDHix_all(v_size, eval, Hi, xHi, xHiDHiDHix_all_gg, xHiDHiDHix_all_ee, xHiDHiDHix_all_ge);
  //assert(xHiDHiDHix_all_gg);
  //assert(xHiDHiDHix_all_ee);
  //assert(xHiDHiDHix_all_ge);

}

unittest{

  DMatrix xHiDHix_all_g = zeros_dmatrix(3, 1);
  DMatrix xHiDHix_all_e = zeros_dmatrix(3, 1);
  DMatrix QixHiy = zeros_dmatrix(3, 1);
  DMatrix xHiDHixQixHiy_all_g = zeros_dmatrix(3, 1);
  DMatrix xHiDHixQixHiy_all_e = zeros_dmatrix(3, 1);

  //Calc_xHiDHixQixHiy_all(xHiDHix_all_g, xHiDHix_all_e, QixHiy, xHiDHixQixHiy_all_g, xHiDHixQixHiy_all_e);
  //assert(xHiDHixQixHiy_all_g);
  //assert(xHiDHixQixHiy_all_e);
}
//
unittest{

  DMatrix Qi =  DMatrix([3, 1], [25, 12, -19]);
  DMatrix vec_all_g = DMatrix([3, 1], [10, 11, 2]);
  DMatrix vec_all_e =  DMatrix([3, 1], [4, 7, 19]);
  DMatrix Qivec_all_g = zeros_dmatrix(3, 1);
  DMatrix Qivec_all_e = zeros_dmatrix(3, 1);

  Calc_QiVec_all(Qi, vec_all_g, vec_all_e, Qivec_all_g, Qivec_all_e);

  assert(Qivec_all_g == DMatrix([3, 1], [250, 120, -190]));
  assert(Qivec_all_e == DMatrix([3, 1], [100, 48, -76]));

}

unittest{

  DMatrix Qi = DMatrix([2, 2], [91, 25, 12, -19]);
  DMatrix mat_all_g = DMatrix([2, 2], [10, 11, 21, 18]);
  DMatrix mat_all_e = DMatrix([2, 2], [4, 9, 11, 12]);
  DMatrix Qimat_all_g = zeros_dmatrix(2, 2);
  DMatrix Qimat_all_e = zeros_dmatrix(2, 2);

  Calc_QiMat_all(Qi, mat_all_g, mat_all_e, Qimat_all_g, Qimat_all_e);

  assert(Qimat_all_g == DMatrix([2, 2], [1435, 1451, -279, -210]));
  assert(Qimat_all_e == DMatrix([2, 2], [639, 1119, -161, -120]));

}

unittest{

  DMatrix eval = DMatrix([3,1], [17, 11, 102]);
  DMatrix Hiy;
  DMatrix QixHiy;
  DMatrix xHiDHiy_all_g;
  DMatrix xHiDHiy_all_e;
  DMatrix xHiDHixQixHiy_all_g;
  DMatrix xHiDHixQixHiy_all_e;
  size_t i;
  size_t j;
  double yPDPy_g = 0;
  double yPDPy_e = 0;

  //Calc_yPDPy(eval, Hiy, QixHiy, xHiDHiy_all_g, xHiDHiy_all_e, xHiDHixQixHiy_all_g, xHiDHixQixHiy_all_e, i, j, yPDPy_g, yPDPy_e);
  //assert(yPDPy_e);
  //assert(yPDPy_g);

}

unittest{

  DMatrix eval;
  DMatrix Hi;
  DMatrix xHi;
  DMatrix Hiy;
  DMatrix QixHiy;
  DMatrix xHiDHiy_all_g;
  DMatrix xHiDHiy_all_e;
  DMatrix QixHiDHiy_all_g;
  DMatrix QixHiDHiy_all_e;
  DMatrix xHiDHixQixHiy_all_g;
  DMatrix xHiDHixQixHiy_all_e;
  DMatrix QixHiDHixQixHiy_all_g;
  DMatrix QixHiDHixQixHiy_all_e;
  DMatrix xHiDHiDHiy_all_gg;
  DMatrix xHiDHiDHiy_all_ee;
  DMatrix xHiDHiDHiy_all_ge;
  DMatrix xHiDHiDHix_all_gg;
  DMatrix xHiDHiDHix_all_ee;
  DMatrix xHiDHiDHix_all_ge;
  size_t i1;
  size_t j1;
  size_t i2;
  size_t j2;
  double yPDPDPy_gg, yPDPDPy_ee, yPDPDPy_ge;
  //Calc_yPDPDPy(eval, Hi, xHi, Hiy, QixHiy, xHiDHiy_all_g, xHiDHiy_all_e,
  //             QixHiDHiy_all_g, QixHiDHiy_all_e, xHiDHixQixHiy_all_g,
  //             xHiDHixQixHiy_all_e, QixHiDHixQixHiy_all_g, QixHiDHixQixHiy_all_e,
  //             xHiDHiDHiy_all_gg,xHiDHiDHiy_all_ee, xHiDHiDHiy_all_ge,
  //             xHiDHiDHix_all_gg, xHiDHiDHix_all_ee, xHiDHiDHix_all_ge,
  //             i1, j1, i2, j2, yPDPDPy_gg, yPDPDPy_ee, yPDPDPy_ge);
  //assert(yPDPDPy_gg);
  //assert(yPDPDPy_ee);
  //assert(yPDPDPy_ge);

}

unittest{

  DMatrix Hessian_inv = DMatrix([3, 3], [ 4,  7, 11,
                                         12, 11, 12,
                                         76, 12, 24 ]);
  DMatrix Qi = DMatrix([3, 3], [ 4, 17, 32,
                                 1, 71, 12,
                                95, 22, 24 ]);
  DMatrix QixHiDHix_all_g = zeros_dmatrix(3, 3);
  DMatrix QixHiDHix_all_e = zeros_dmatrix(3, 3);
  DMatrix xHiDHiDHix_all_gg = zeros_dmatrix(3, 3);
  DMatrix xHiDHiDHix_all_ee = zeros_dmatrix(3, 3);
  DMatrix xHiDHiDHix_all_ge = zeros_dmatrix(3, 3);
  size_t d_size = 2;
  double crt_a, crt_b, crt_c;

  CalcCRT(Hessian_inv, Qi, QixHiDHix_all_g, QixHiDHix_all_e, xHiDHiDHix_all_gg,
    xHiDHiDHix_all_ee, xHiDHiDHix_all_ge, d_size, crt_a, crt_b, crt_c);
  writeln(crt_a);
  writeln(crt_b);
  writeln(crt_c);

}

unittest{

  size_t mode = 1;
  size_t d_size = 3;
  double p_value = 0.62;
  double crt_a = 0.51;
  double crt_b = 0.88;
  double crt_c = 0.32;

  double pcrt = PCRT(mode, d_size, p_value, crt_a, crt_b, crt_c);
  assert(abs(pcrt - 0.699685) < 1e-03);
}

unittest{

  DMatrix Y = DMatrix([3,3], [ 11,2,11,
                              21, 12, 13,
                              99, 78, 62]);
  DMatrix Hi_all = DMatrix([6,6], [5, 12, 32,  0, -9, 9,
                                  12, 90, 32, 82, 88, 11,
                                  64, 98, 67,  75, -10, 12,
                                  18, 67, 88, -175, 39, -3,
                                  15, 44, 56, 75, -9, -55,
                                -975, 15, 89, 75, 11, -13,
                                   ]);

  DMatrix Hiy_all = DMatrix([3,3], [ 99, -78, 26,
                                   121,  66,  3,
                                    45,  72, 11]);
  Calc_Hiy_all(Y, Hi_all, Hiy_all);
  assert(eqeq(Hiy_all, DMatrix([3, 3], [3475,  594, 3286,
                                        5190, 2078, 6132,
                                        9395,  966, 6525])));

}

unittest{

  DMatrix X = DMatrix([2,3], [ 11,2,11,
                              99, 78, 62]);
  DMatrix xHi_all = zeros_dmatrix(12,12);
  //DMatrix([6,6], [5, 12, 32,  0, -9, 9,
  //                                12, 90, 32, 82, 88, 11,
  //                                64, 98, 67,  75, -10, 12,
  //                                18, 67, 88, -175, 39, -3,
  //                                15, 44, 56, 75, -9, -55,
  //                              -975, 15, 89, 75, 11, -13,
  //                                 ]);
  DMatrix Hi_all = DMatrix([2,3], [ 99, -78, 26,
                                    45,  72, 11]);
  //Calc_xHi_all(X, Hi_all, xHi_all);
  //write("xHi_all => ", xHi_all);
  //assert(xHi_all == DMatrix([], []));

}

unittest{

  DMatrix Y = DMatrix([2,3], [ 11,  2, 11,
                               99, 78, 62]);
  DMatrix Hiy_all = DMatrix([6,6], [5, 12, 32,    0,  -9,   9,
                                   12, 90, 32,   82,  88,  11,
                                   64, 98, 67,   75, -10,  12,
                                   18, 67, 88, -175,  39,  -3,
                                   15, 44, 56,   75,  -9, -55,
                                 -975, 15, 89,   75,  11, -13]);
  double yHiy = Calc_yHiy(Y, Hiy_all);
  assert(yHiy == 10623);
}

unittest{

  DMatrix Y = DMatrix([3,3], [ 11,  2, 11,
                              121,  66,  3,
                               99, 78, 62]);
  DMatrix x = DMatrix([3,1], [15, 16, 7]);
  DMatrix Hi = DMatrix([1,9], [3, 5, 89, 1, 21, 12, 54, -7, 82]);
  DMatrix xHi = matrix_mult(x, Hi);
  DMatrix xHiy = DMatrix([3,1], [5, 6, 7]);
  Calc_xHiy(Y, xHi, xHiy);
  assert(eqeq(xHiy, DMatrix([3, 1], [261450, 278880, 122010])));

}

unittest{

  DMatrix eval = DMatrix([27,1], [102, -19, -12, 19, 24, 72, -19, 14, 24,
                                  102, -19, -12, 19, 24, 72, -19, 14, 24,
                                  102, -19, -12, 19, 24, 72, -19, 14, 24]);
  DMatrix Qi = zeros_dmatrix(4,4);
  DMatrix Hi = zeros_dmatrix(2,28);
  DMatrix xHiDHix_all_g = zeros_dmatrix(4, 12);
  DMatrix xHiDHix_all_e = zeros_dmatrix(4, 12);
  size_t i = 0;
  size_t j = 0;
  double tPD_g, tPD_e;
  Calc_tracePD(eval, Qi, Hi, xHiDHix_all_g, xHiDHix_all_e, i, j, tPD_g, tPD_e);
  writeln("tPD_g  => ", tPD_g);
  writeln("tPD_e  => ", tPD_e);
  assert(tPD_g == 0);  // TODO => Get rid of zeros matrix
  assert(tPD_e == 0);

}

unittest{
  DMatrix eval = DMatrix([27,1], [102, -19, -12, 19, 24, 72, -19, 14, 24,
                                  102, -19, -12, 19, 24, 72, -19, 14, 24,
                                  102, -19, -12, 19, 24, 72, -19, 14, 24]);
  DMatrix Qi = zeros_dmatrix(4,4);
  DMatrix Hi = zeros_dmatrix(2,28);
  DMatrix xHi = zeros_dmatrix(4,28);

  DMatrix QixHiDHix_all_g = zeros_dmatrix(4, 12);
  DMatrix QixHiDHix_all_e = zeros_dmatrix(4, 12);
  DMatrix xHiDHiDHix_all_gg = zeros_dmatrix(4, 12);
  DMatrix xHiDHiDHix_all_ee = zeros_dmatrix(4, 12);
  DMatrix xHiDHiDHix_all_ge = zeros_dmatrix(4, 12);
  size_t i1, j1, i2, j2;
  double tPDPD_gg, tPDPD_ee, tPDPD_ge;

  Calc_tracePDPD(eval, Qi, Hi, xHi, QixHiDHix_all_g, QixHiDHix_all_e,
                 xHiDHiDHix_all_gg, xHiDHiDHix_all_ee, xHiDHiDHix_all_ge,
                 i1, j1, i2, j2,
                 tPDPD_gg, tPDPD_ee, tPDPD_ge);  // TODO => Get rid of zeros matrix
  assert(tPDPD_gg == 0);
  assert(tPDPD_ee == 0);
  assert(tPDPD_ge == 0);

}

unittest{


  DMatrix eval = DMatrix([27,1], [102, -19, -12, 19, 24, 72, -19, 14, 24,
                                  102, -19, -12, 19, 24, 72, -19, 14, 24,
                                  102, -19, -12, 19, 24, 72, -19, 14, 24]);
  DMatrix Hi = zeros_dmatrix(2,28);
  DMatrix xHiDHix_all_g = zeros_dmatrix(4, 12);
  DMatrix xHiDHix_all_e = zeros_dmatrix(4, 12);
  size_t i = 0;
  size_t j = 0;
  double tHiD_g = 0;
  double tHiD_e = 0;
  Calc_traceHiD(eval, Hi, i, j, tHiD_g, tHiD_e);

  assert(tHiD_g == 0);  // TODO => Get rid of zeros matrix
  assert(tHiD_e == 0);

}

unittest{

  DMatrix eval = DMatrix([27,1], [102, -19, -12, 19, 24, 72, -19, 14, 24,
                                  102, -19, -12, 19, 24, 72, -19, 14, 24,
                                  102, -19, -12, 19, 24, 72, -19, 14, 24]);
  DMatrix Hi = zeros_dmatrix(2,28);
  size_t i1 = 0;
  size_t j1 = 0;
  size_t i2 = 0;
  size_t j2 = 0;
  double tHiDHiD_gg = 0, tHiDHiD_ee = 0, tHiDHiD_ge = 0;

  Calc_traceHiDHiD(eval, Hi, i1, j1, i2, j2, tHiDHiD_gg, tHiDHiD_ee, tHiDHiD_ge);
  assert(tHiDHiD_gg == 0);
  assert(tHiDHiD_ee == 0);
  assert(tHiDHiD_ge == 0);

}

unittest{
  DMatrix eval = DMatrix([2,1], [102, -19]);
  DMatrix x = DMatrix([8, 1], [71, 3, 75, 12, -22, 234, 67, 12]);
  DMatrix Hi = DMatrix([1, 8], [32, 5, 12, -2, 71, 4, 88, -21]);
  DMatrix xHi = matrix_mult(x, Hi);

  DMatrix Hiy = ones_dmatrix(4,  2);

  size_t i = 0;
  size_t j = 0;
  DMatrix xHiDHiy_g = ones_dmatrix(8,1);
  DMatrix xHiDHiy_e = ones_dmatrix(8,1);

  Calc_xHiDHiy(eval, xHi, Hiy, i, j, xHiDHiy_g, xHiDHiy_e);
  writeln("xHiDHiy_g => ", xHiDHiy_g);
  writeln("xHiDHiy_e => ", xHiDHiy_e);

  assert(eqeq(xHiDHiy_g, DMatrix([1, 8], [135965, 5745, 143625, 22980, -42130, 448110, 128305, 22980])));
  assert(eqeq(xHiDHiy_e, DMatrix([1, 8], [7313, 309, 7725, 1236, -2266, 24102, 6901, 1236])));

}

unittest{

  DMatrix eval = DMatrix([2,1], [10, -19]);
  DMatrix x = DMatrix([8, 1], [71, 3, 75, 12, -22, 234, 67, 12]);
  DMatrix Hi = DMatrix([1, 8], [32, 5, 12, -2, 71, 4, 88, -21]);
  DMatrix xHi = matrix_mult(x, Hi);
  size_t i = 0;
  size_t j = 0;
  DMatrix xHiDHix_g = ones_dmatrix(8,8);
  DMatrix xHiDHix_e = ones_dmatrix(8,8);
  Calc_xHiDHix(eval, xHi, i, j, xHiDHix_g, xHiDHix_e);
  writeln("xHiDHiy_g => ", xHiDHix_g);
  writeln("xHiDHiy_e => ", xHiDHix_e);

  //assert(xHiDHix_g == DMatrix([], [])); // TODO
  //assert(xHiDHix_e == DMatrix([], []));

}

unittest{
  DMatrix eval = DMatrix([2,1], [102, -19]);
  DMatrix x = DMatrix([8, 1], [71, 3, 75, 12, -22, 234, 67, 12]);
  DMatrix Hi = DMatrix([1, 8], [32, 5, 12, -2, 71, 4, 88, -21]);
  DMatrix xHi = matrix_mult(x, Hi);
  DMatrix Hiy = DMatrix([2, 2], [1,2,3,4]);
  size_t i1 = 0;
  size_t j1 = 0;
  size_t i2 = 0;
  size_t j2 = 0;
  DMatrix xHiDHiDHiy_gg = ones_dmatrix(8,1); // change 8 to 2 : breaks
  DMatrix xHiDHiDHiy_ee = ones_dmatrix(8,1);
  DMatrix xHiDHiDHiy_ge = ones_dmatrix(8,1);

  Calc_xHiDHiDHiy(eval, Hi, xHi, Hiy, i1, j1, i2, j2, xHiDHiDHiy_gg, xHiDHiDHiy_ee, xHiDHiDHiy_ge);
  writeln("xHiDHiDHiy_gg => ", xHiDHiDHiy_gg);
  writeln("xHiDHiDHiy_ee => ", xHiDHiDHiy_ee);
  writeln("xHiDHiDHiy_ge => ", xHiDHiDHiy_ge);
  //assert(xHiDHiDHiy_gg == DMatrix([], []));  // TODO
  //assert(xHiDHiDHiy_ee == DMatrix([], []));
  //assert(xHiDHiDHiy_ge == DMatrix([], []));

}

unittest{

  DMatrix eval = DMatrix([2,1], [102, -19]);
  DMatrix x = DMatrix([8, 1], [71, 3, 75, 12, -22, 234, 67, 12]);
  DMatrix Hi = DMatrix([1, 8], [32, 5, 12, -2, 71, 4, 88, -21]);
  DMatrix xHi = matrix_mult(x, Hi);
  size_t i1 = 0;
  size_t j1 = 0;
  size_t i2 = 0;
  size_t j2 = 0;
  DMatrix xHiDHiDHix_gg = ones_dmatrix(8,8);
  DMatrix xHiDHiDHix_ee = ones_dmatrix(8,8);
  DMatrix xHiDHiDHix_ge = ones_dmatrix(8,8);

  Calc_xHiDHiDHix(eval, Hi, xHi, i1, j1, i2, j2, xHiDHiDHix_gg, xHiDHiDHix_ee,  xHiDHiDHix_ge);
  writeln("xHiDHiDHix_gg => ", xHiDHiDHix_gg);
  writeln("xHiDHiDHix_ee => ", xHiDHiDHix_ee);
  writeln("xHiDHiDHix_ge => ", xHiDHiDHix_ge);

  //assert(xHiDHiDHix_gg == DMatrix([], [])); // TODO: check
  //assert(xHiDHiDHix_ee == DMatrix([], []));
  //assert(xHiDHiDHix_ge == DMatrix([], []));
}

unittest{

  DMatrix eval = DMatrix([2,1], [102, -19]);
  DMatrix Hiy = ones_dmatrix(4,  2);
  size_t i = 0;
  size_t j = 1;
  double yHiDHiy_g = 0;
  double yHiDHiy_e = 0;

  Calc_yHiDHiy(eval, Hiy, i, j, yHiDHiy_g, yHiDHiy_e);

  assert(yHiDHiy_g == 166);
  assert(yHiDHiy_e == 4);

}

unittest{

  DMatrix eval = DMatrix([2,1], [102, -19]);
  DMatrix Hi = DMatrix([1, 8], [32, 5, 12, -2, 71, 4, 88, -21]);
  DMatrix Hiy = DMatrix([2, 2], [1,2,3,4]);
  size_t i1 = 0;
  size_t j1 = 0;
  size_t i2 = 0;
  size_t j2 = 0;
  double yHiDHiDHiy_gg = 0;
  double yHiDHiDHiy_ee = 0;
  double yHiDHiDHiy_ge = 0;

  Calc_yHiDHiDHiy(eval, Hi, Hiy, i1, j1, i2, j2, yHiDHiDHiy_gg, yHiDHiDHiy_ee, yHiDHiDHiy_ge);

  assert(yHiDHiDHiy_gg == 350256);
  assert(yHiDHiDHiy_ee == 80);
  assert(yHiDHiDHiy_ge == 2352);
}
