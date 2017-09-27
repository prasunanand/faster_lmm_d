/*
   This code is part of faster_lmm_d and published under the GPLv3
   License (see LICENSE.txt)

   Copyright © 2017 Prasun Anand & Pjotr Prins
*/

module faster_lmm_d.gemma_lmm;

import std.conv;
import std.exception;
import std.math;
alias mlog = std.math.log;
import std.stdio;
import std.typecons;
import std.experimental.logger;

import faster_lmm_d.dmatrix;
import faster_lmm_d.optmatrix;

import gsl.cdf;
import gsl.errno;
import gsl.math;
import gsl.min;
import gsl.roots;

void CalcPab(const size_t n_cvt, const size_t e_mode, const DMatrix Hi_eval,
             const DMatrix Uab, const DMatrix ab, DMatrix Pab) {
  size_t index_ab, index_aw, index_bw, index_ww;
  double p_ab;
  double ps_ab, ps_aw, ps_bw, ps_ww;

  for (size_t p = 0; p <= n_cvt + 1; ++p) {
    for (size_t a = p + 1; a <= n_cvt + 2; ++a) {
      for (size_t b = a; b <= n_cvt + 2; ++b) {
        index_ab = GetabIndex(a, b, n_cvt);
        if (p == 0) {
          DMatrix Uab_col = get_col(Uab, index_ab);
          p_ab = matrix_mult(Hi_eval, Uab_col).elements[0];  // check its shape is [1,1] else take transpose of Hi_eval
          if (e_mode != 0) {
            p_ab = ab.elements[index_ab] - p_ab;
          }
          Pab.elements[index_ab] = p_ab;
        } else {
          index_aw = GetabIndex(a, p, n_cvt);
          index_bw = GetabIndex(b, p, n_cvt);
          index_ww = GetabIndex(p, p, n_cvt);

          ps_ab = accessor(Pab, p - 1, index_ab);
          ps_aw = accessor(Pab, p - 1, index_aw);
          ps_bw = accessor(Pab, p - 1, index_bw);
          ps_ww = accessor(Pab, p - 1, index_ww);

          p_ab = ps_ab - ps_aw * ps_bw / ps_ww;
          Pab.elements[p * Pab.cols + index_ab] = p_ab;
        }
      }
    }
  }
  return;
}


void CalcPPab(const size_t n_cvt, const size_t e_mode,
              const DMatrix HiHi_eval, const DMatrix Uab,
              const DMatrix ab, const DMatrix Pab, DMatrix PPab) {
  size_t index_ab, index_aw, index_bw, index_ww;
  double p2_ab;
  double ps2_ab, ps_aw, ps_bw, ps_ww, ps2_aw, ps2_bw, ps2_ww;

  for (size_t p = 0; p <= n_cvt + 1; ++p) {
    for (size_t a = p + 1; a <= n_cvt + 2; ++a) {
      for (size_t b = a; b <= n_cvt + 2; ++b) {
        index_ab = GetabIndex(a, b, n_cvt);
        if (p == 0) {
          DMatrix Uab_col = get_col(Uab, index_ab);
          p2_ab = matrix_mult(HiHi_eval, Uab_col).elements[0];  // check its shape is [1,1] else take transpose of HiHi_eval
          if (e_mode != 0) {
            p2_ab = p2_ab - ab.elements[index_ab] +
                    2.0 * Pab.elements[index_ab];
          }
          PPab.elements[index_ab] = p2_ab;
        } else {
          index_aw = GetabIndex(a, p, n_cvt);
          index_bw = GetabIndex(b, p, n_cvt);
          index_ww = GetabIndex(p, p, n_cvt);

          ps2_ab = accessor(PPab, p - 1, index_ab);
          ps_aw = accessor(Pab, p - 1, index_aw);
          ps_bw = accessor(Pab, p - 1, index_bw);
          ps_ww = accessor(Pab, p - 1, index_ww);
          ps2_aw = accessor(PPab, p - 1, index_aw);
          ps2_bw = accessor(PPab, p - 1, index_bw);
          ps2_ww = accessor(PPab, p - 1, index_ww);

          p2_ab = ps2_ab + ps_aw * ps_bw * ps2_ww / (ps_ww * ps_ww);
          p2_ab -= (ps_aw * ps2_bw + ps_bw * ps2_aw) / ps_ww;
          PPab.elements[p * PPab.cols + index_ab] = p2_ab;
        }
      }
    }
  }
  return;
}

void CalcPPPab(const size_t n_cvt, const size_t e_mode,
               const DMatrix HiHiHi_eval, const DMatrix Uab,
               const DMatrix ab, const DMatrix Pab,
               const DMatrix PPab, DMatrix PPPab) {
  size_t index_ab, index_aw, index_bw, index_ww;
  double p3_ab;
  double ps3_ab, ps_aw, ps_bw, ps_ww, ps2_aw, ps2_bw, ps2_ww, ps3_aw, ps3_bw,
      ps3_ww;

  for (size_t p = 0; p <= n_cvt + 1; ++p) {
    for (size_t a = p + 1; a <= n_cvt + 2; ++a) {
      for (size_t b = a; b <= n_cvt + 2; ++b) {
        index_ab = GetabIndex(a, b, n_cvt);
        if (p == 0) {
          DMatrix Uab_col = get_col(Uab, index_ab);
          p3_ab = matrix_mult(HiHiHi_eval, Uab_col).elements[0];
          if (e_mode != 0) {
            p3_ab = ab.elements[index_ab] - p3_ab +
                    3.0 * accessor(PPab, 0, index_ab) -
                    3.0 * accessor(Pab, 0, index_ab);
          }
          PPPab.elements[0* PPPab.cols + index_ab] = p3_ab;
        } else {
          index_aw = GetabIndex(a, p, n_cvt);
          index_bw = GetabIndex(b, p, n_cvt);
          index_ww = GetabIndex(p, p, n_cvt);

          ps3_ab = accessor(PPPab, p - 1, index_ab);
          ps_aw = accessor(Pab, p - 1, index_aw);
          ps_bw = accessor(Pab, p - 1, index_bw);
          ps_ww = accessor(Pab, p - 1, index_ww);
          ps2_aw = accessor(PPab, p - 1, index_aw);
          ps2_bw = accessor(PPab, p - 1, index_bw);
          ps2_ww = accessor(PPab, p - 1, index_ww);
          ps3_aw = accessor(PPPab, p - 1, index_aw);
          ps3_bw = accessor(PPPab, p - 1, index_bw);
          ps3_ww = accessor(PPPab, p - 1, index_ww);

          p3_ab = ps3_ab -
                  ps_aw * ps_bw * ps2_ww * ps2_ww / (ps_ww * ps_ww * ps_ww);
          p3_ab -= (ps_aw * ps3_bw + ps_bw * ps3_aw + ps2_aw * ps2_bw) / ps_ww;
          p3_ab += (ps_aw * ps2_bw * ps2_ww + ps_bw * ps2_aw * ps2_ww +
                    ps_aw * ps_bw * ps3_ww) /
                   (ps_ww * ps_ww);

          PPPab.elements[p* PPPab.cols + index_ab] = p3_ab;
        }
      }
    }
  }
  return;
}

size_t GetabIndex(size_t a, size_t b, size_t n_cvt) {
  size_t n = n_cvt + 2;
  if (a > n || b > n || a <= 0 || b <= 0) {
    writeln("error in GetabIndex.");
    return 0;
  }

  if (b < a) {
    size_t temp = b;
    b = a;
    a = temp;
  }

  return (2 * n - a + 2) * (a - 1) / 2 + b - a;
}

struct loglikeparam{
  size_t n_cvt;
  size_t ni_test;
  size_t n_index;
  bool calc_null;
  int e_mode;
  DMatrix eval;
  DMatrix Uab;
  DMatrix ab;
}

double LogL_f(double l, void* params) {
  auto ptr = cast(loglikeparam *)params;
  loglikeparam p = *ptr;

  size_t n_cvt = p.n_cvt;
  size_t ni_test = p.ni_test;
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  size_t nc_total;
  if (p.calc_null == true) {
    nc_total = n_cvt;
  } else {
    nc_total = n_cvt + 1;
  }

  double f = 0.0;
  double logdet_h = 0.0;
  double d;
  size_t index_yy;

  DMatrix Pab;
  Pab.shape = [n_cvt + 2, n_index];
  DMatrix Hi_eval;
  Hi_eval.shape = [1, p.eval.elements.length];
  DMatrix v_temp;
  v_temp.shape = [1, p.eval.elements.length];

  v_temp.elements = p.eval.elements;

  v_temp = multiply_dmatrix_num(v_temp, l);

  if (p.e_mode == 0) {
    //gsl_vector_set_all(Hi_eval, 1.0);
  } else {
    Hi_eval.elements = v_temp.elements;
  }

  v_temp = add_dmatrix_num(v_temp, 1.0);
  Hi_eval = divide_dmatrix(Hi_eval, v_temp);

  for (size_t i = 0; i < p.eval.elements.length; ++i) {
    d = v_temp.elements[i];
    logdet_h += mlog(fabs(d));
  }

  CalcPab(n_cvt, p.e_mode, Hi_eval, p.Uab, p.ab, Pab);

  double c = 0.5 * to!double(ni_test) * (mlog(to!double(ni_test)) - mlog(2 * M_PI) - 1.0);

  index_yy = GetabIndex(n_cvt + 2, n_cvt + 2, n_cvt);
  double P_yy = accessor(Pab, nc_total, index_yy);
  f = c - 0.5 * logdet_h - 0.5 * to!double(ni_test) * mlog(P_yy);

  return f;
}

double LogRL_f(double l, void* params) {
  auto ptr = cast(loglikeparam *)params;
  loglikeparam p = *ptr;

  size_t n_cvt = p.n_cvt;
  size_t ni_test = p.ni_test;
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  double df;
  size_t nc_total;
  if (p.calc_null == true) {
    nc_total = n_cvt;
    df = to!double(ni_test) - to!double(n_cvt);
  } else {
    nc_total = n_cvt + 1;
    df = to!double(ni_test) - to!double(n_cvt) - 1.0;
  }

  double f = 0.0, logdet_h = 0.0, logdet_hiw = 0.0, d;
  size_t index_ww;

  DMatrix Pab;
  Pab.shape = [n_cvt + 2, n_index];
  DMatrix Iab;
  Iab.shape = [n_cvt + 2, n_index];
  DMatrix Hi_eval;
  Hi_eval.shape = [1, p.eval.elements.length];
  DMatrix v_temp;
  v_temp.shape = [1, p.eval.elements.length];
  v_temp.elements = p.eval.elements;

  v_temp = multiply_dmatrix_num(v_temp, l);
  if (p.e_mode == 0) {
    //gsl_vector_set_all(Hi_eval, 1.0);
  } else {
    Hi_eval.elements = v_temp.elements;
  }
  v_temp = add_dmatrix_num(v_temp, 1.0);
  Hi_eval = divide_dmatrix(Hi_eval, v_temp);

  for (size_t i = 0; i < p.eval.elements.length; ++i) {
    d = v_temp.elements[i];
    logdet_h += mlog(fabs(d));
  }

  CalcPab(n_cvt, p.e_mode, Hi_eval, p.Uab, p.ab, Pab);

  //gsl_vector_set_all(v_temp, 1.0);
  CalcPab(n_cvt, p.e_mode, v_temp, p.Uab, p.ab, Iab);

  // Calculate |WHiW|-|WW|.
  logdet_hiw = 0.0;
  for (size_t i = 0; i < nc_total; ++i) {
    index_ww = GetabIndex(i + 1, i + 1, n_cvt);
    d = accessor(Pab, i, index_ww);
    logdet_hiw += mlog(d);
    d = accessor(Iab, i, index_ww);
    logdet_hiw -= mlog(d);
  }
  index_ww = GetabIndex(n_cvt + 2, n_cvt + 2, n_cvt);
  double P_yy = accessor(Pab, nc_total, index_ww);

  double c = 0.5 * df * (mlog(df) - mlog(2 * M_PI) - 1.0);
  f = c - 0.5 * logdet_h - 0.5 * logdet_hiw - 0.5 * df * mlog(P_yy);

  return f;
}

extern(C) double LogRL_dev1(double l, void* params) {
  auto ptr = cast(loglikeparam *)params;
  loglikeparam p = *ptr;

  size_t n_cvt = p.n_cvt;
  size_t ni_test = p.ni_test;
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  double df;
  size_t nc_total;
  if (p.calc_null == true) {
    nc_total = n_cvt;
    df = to!double(ni_test) - to!double(n_cvt);
  } else {
    nc_total = n_cvt + 1;
    df = to!double(ni_test) - to!double(n_cvt) - 1.0;
  }

  double dev1 = 0.0, trace_Hi = 0.0;
  size_t index_ww;

  DMatrix Pab;
  Pab.shape = [n_cvt + 2, n_index];

  DMatrix PPab;
  PPab.shape = [n_cvt + 2, n_index];

  DMatrix Hi_eval;
  Hi_eval.shape = [1, p.eval.elements.length];
  DMatrix HiHi_eval;
  HiHi_eval.shape = [1, p.eval.elements.length];
  DMatrix v_temp;
  v_temp.shape = [1, p.eval.elements.length];
  v_temp.elements = p.eval.elements;

  v_temp = multiply_dmatrix_num(v_temp, l);
  if (p.e_mode == 0) {
    //gsl_vector_set_all(Hi_eval, 1.0);
  } else {
    Hi_eval.elements = v_temp.elements;
  }

  v_temp = add_dmatrix_num(v_temp, 1.0);
  Hi_eval = divide_dmatrix(Hi_eval, v_temp);


  HiHi_eval.elements =  Hi_eval.elements.dup;
  HiHi_eval = slow_multiply_dmatrix(HiHi_eval, Hi_eval);

  //gsl_vector_set_all(v_temp, 1.0);
  trace_Hi = matrix_mult(Hi_eval, v_temp).elements[0];

  if (p.e_mode != 0) {
    trace_Hi = to!double(ni_test) - trace_Hi;
  }

  CalcPab(n_cvt, p.e_mode, Hi_eval, p.Uab, p.ab, Pab);
  CalcPPab(n_cvt, p.e_mode, HiHi_eval, p.Uab, p.ab, Pab, PPab);

  // Calculate tracePK and trace PKPK.
  double trace_P = trace_Hi;
  double ps_ww, ps2_ww;
  for (size_t i = 0; i < nc_total; ++i) {
    index_ww = GetabIndex(i + 1, i + 1, n_cvt);
    ps_ww = accessor(Pab, i, index_ww);
    ps2_ww = accessor(PPab, i, index_ww);
    trace_P -= ps2_ww / ps_ww;
  }
  double trace_PK = (df - trace_P) / l;

  // Calculate yPKPy, yPKPKPy.
  index_ww = GetabIndex(n_cvt + 2, n_cvt + 2, n_cvt);
  double P_yy = accessor(Pab, nc_total, index_ww);
  double PP_yy = accessor(PPab, nc_total, index_ww);
  double yPKPy = (P_yy - PP_yy) / l;

  dev1 = -0.5 * trace_PK + 0.5 * df * yPKPy / P_yy;

  return dev1;
}

extern(C) double LogL_dev1(double l, void* params) {
  auto ptr = cast(loglikeparam *)params;
  loglikeparam p = *ptr;

  size_t n_cvt = p.n_cvt;
  size_t ni_test = p.ni_test;
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  size_t nc_total;

  if (p.calc_null == true) {
    nc_total = n_cvt;
  } else {
    nc_total = n_cvt + 1;
  }

  double dev1 = 0.0, trace_Hi = 0.0;
  size_t index_yy;

  DMatrix Pab;
  Pab.shape = [n_cvt + 2, n_index];

  DMatrix PPab;
  PPab.shape = [n_cvt + 2, n_index];

  DMatrix Hi_eval;
  Hi_eval.shape = [1, p.eval.elements.length];
  DMatrix HiHi_eval;
  HiHi_eval.shape = [1, p.eval.elements.length];
  DMatrix v_temp;
  v_temp.shape = [1, p.eval.elements.length];
  v_temp.elements = p.eval.elements;

  v_temp = multiply_dmatrix_num(v_temp, l);

  if (p.e_mode == 0) {
    //gsl_vector_set_all(Hi_eval, 1.0);
  } else {
    Hi_eval.elements = v_temp.elements.dup;
  }
  v_temp = add_dmatrix_num(v_temp, 1.0);
  HiHi_eval = divide_dmatrix(Hi_eval, v_temp);

  HiHi_eval.elements = Hi_eval.elements.dup;
  HiHi_eval = slow_multiply_dmatrix(HiHi_eval, Hi_eval);

  //gsl_vector_set_all(v_temp, 1.0);
  trace_Hi = matrix_mult(Hi_eval, v_temp).elements[0];

  if (p.e_mode != 0) {
    trace_Hi = to!double(ni_test) - trace_Hi;
  }

  CalcPab(n_cvt, p.e_mode, Hi_eval, p.Uab, p.ab, Pab);
  CalcPPab(n_cvt, p.e_mode, HiHi_eval, p.Uab, p.ab, Pab, PPab);

  double trace_HiK = (to!double(ni_test) - trace_Hi) / l;

  index_yy = GetabIndex(n_cvt + 2, n_cvt + 2, n_cvt);

  double P_yy = accessor(Pab, nc_total, index_yy);
  double PP_yy = accessor(PPab, nc_total, index_yy);
  double yPKPy = (P_yy - PP_yy) / l;
  dev1 = -0.5 * trace_HiK + 0.5 * to!double(ni_test) * yPKPy / P_yy;

  return dev1;
}

extern(C) double LogRL_dev2(double l, void* params) {
  auto ptr = cast(loglikeparam *)params;
  loglikeparam p = *ptr;

  size_t n_cvt = p.n_cvt;
  size_t ni_test = p.ni_test;
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  double df;
  size_t nc_total;
  if (p.calc_null == true) {
    nc_total = n_cvt;
    df = to!double(ni_test) - to!double(n_cvt);
  } else {
    nc_total = n_cvt + 1;
    df = to!double(ni_test) - to!double(n_cvt) - 1.0;
  }

  double dev2 = 0.0, trace_Hi = 0.0, trace_HiHi = 0.0;
  size_t index_ww;

  DMatrix Pab;
  Pab.shape = [n_cvt + 2, n_index];

  DMatrix PPab;
  PPab.shape = [n_cvt + 2, n_index];

  DMatrix PPPab;
  PPab.shape = [n_cvt + 2, n_index];

  DMatrix Hi_eval;
  Hi_eval.shape = [1, p.eval.elements.length];
  DMatrix HiHi_eval;
  HiHi_eval.shape = [1, p.eval.elements.length];
  DMatrix HiHiHi_eval;
  HiHi_eval.shape = [1, p.eval.elements.length];
  DMatrix v_temp;
  v_temp.shape = [1, p.eval.elements.length];
  v_temp.elements = p.eval.elements;

  v_temp = multiply_dmatrix_num(v_temp, l);


  if (p.e_mode == 0) {
    //gsl_vector_set_all(Hi_eval, 1.0);
  } else {
    Hi_eval.elements = v_temp.elements.dup;
  }
  v_temp = add_dmatrix_num(v_temp, 1.0);
  Hi_eval = divide_dmatrix(Hi_eval, v_temp);

  HiHi_eval.elements = Hi_eval.elements.dup;
  HiHi_eval = slow_multiply_dmatrix(HiHi_eval, Hi_eval);
  HiHiHi_eval.elements = HiHi_eval.elements.dup;
  HiHiHi_eval = slow_multiply_dmatrix(HiHiHi_eval, Hi_eval);

  //gsl_vector_set_all(v_temp, 1.0);
  trace_Hi = matrix_mult(Hi_eval, v_temp).elements[0];
  trace_HiHi = matrix_mult(HiHi_eval, v_temp).elements[0];

  if (p.e_mode != 0) {
    trace_Hi = to!double(ni_test) - trace_Hi;
    trace_HiHi = 2 * trace_Hi + trace_HiHi - to!double(ni_test);
  }

  CalcPab(n_cvt, p.e_mode, Hi_eval, p.Uab, p.ab, Pab);
  CalcPPab(n_cvt, p.e_mode, HiHi_eval, p.Uab, p.ab, Pab, PPab);
  CalcPPPab(n_cvt, p.e_mode, HiHiHi_eval, p.Uab, p.ab, Pab, PPab, PPPab);

  // Calculate tracePK and trace PKPK.
  double trace_P = trace_Hi, trace_PP = trace_HiHi;
  double ps_ww, ps2_ww, ps3_ww;
  for (size_t i = 0; i < nc_total; ++i) {
    index_ww = GetabIndex(i + 1, i + 1, n_cvt);
    ps_ww = accessor(Pab, i, index_ww);
    ps2_ww = accessor(PPab, i, index_ww);
    ps3_ww = accessor(PPPab, i, index_ww);
    trace_P -= ps2_ww / ps_ww;
    trace_PP += ps2_ww * ps2_ww / (ps_ww * ps_ww) - 2.0 * ps3_ww / ps_ww;
  }
  double trace_PKPK = (df + trace_PP - 2.0 * trace_P) / (l * l);

  // Calculate yPKPy, yPKPKPy.
  index_ww = GetabIndex(n_cvt + 2, n_cvt + 2, n_cvt);
  double P_yy = accessor(Pab, nc_total, index_ww);
  double PP_yy = accessor(PPab, nc_total, index_ww);
  double PPP_yy = accessor(PPPab, nc_total, index_ww);
  double yPKPy = (P_yy - PP_yy) / l;
  double yPKPKPy = (P_yy + PPP_yy - 2.0 * PP_yy) / (l * l);

  dev2 = 0.5 * trace_PKPK -
         0.5 * df * (2.0 * yPKPKPy * P_yy - yPKPy * yPKPy) / (P_yy * P_yy);

  return dev2;
}

extern(C) double LogL_dev2(double l, void* params) {
  auto ptr = cast(loglikeparam *)params;
  loglikeparam p = *ptr;

  size_t n_cvt = p.n_cvt;
  size_t ni_test = p.ni_test;
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  size_t nc_total;
  if (p.calc_null == true) {
    nc_total = n_cvt;
  } else {
    nc_total = n_cvt + 1;
  }

  double dev2 = 0.0, trace_Hi = 0.0, trace_HiHi = 0.0;
  size_t index_yy;

  DMatrix Pab;
  Pab.shape = [n_cvt + 2, n_index];

  DMatrix PPab;
  PPab.shape = [n_cvt + 2, n_index];

  DMatrix PPPab;
  PPab.shape = [n_cvt + 2, n_index];

  DMatrix Hi_eval;
  Hi_eval.shape = [1, p.eval.elements.length];
  DMatrix HiHi_eval;
  HiHi_eval.shape = [1, p.eval.elements.length];
  DMatrix HiHiHi_eval;
  HiHi_eval.shape = [1, p.eval.elements.length];
  DMatrix v_temp;
  v_temp.shape = [1, p.eval.elements.length];
  v_temp.elements = p.eval.elements;

  v_temp = multiply_dmatrix_num(v_temp, l);

  if (p.e_mode == 0) {
    //gsl_vector_set_all(Hi_eval, 1.0);
  } else {
    Hi_eval.elements = v_temp.elements.dup;
  }
  v_temp = add_dmatrix_num(v_temp, 1.0);
  Hi_eval = divide_dmatrix(Hi_eval, v_temp);

  HiHi_eval.elements = Hi_eval.elements.dup;
  HiHi_eval = matrix_mult(HiHi_eval, Hi_eval); // gsl_vector_mul();
  HiHiHi_eval.elements = HiHi_eval.elements.dup;
  HiHiHi_eval = matrix_mult(HiHiHi_eval, Hi_eval);

  //gsl_vector_set_all(v_temp, 1.0);
  trace_Hi = matrix_mult(Hi_eval, v_temp).elements[0];
  trace_HiHi = matrix_mult(HiHi_eval, v_temp).elements[0];

  if (p.e_mode != 0) {
    trace_Hi = to!double(ni_test) - trace_Hi;
    trace_HiHi = 2 * trace_Hi + trace_HiHi - to!double(ni_test);
  }

  CalcPab(n_cvt, p.e_mode, Hi_eval, p.Uab, p.ab, Pab);
  CalcPPab(n_cvt, p.e_mode, HiHi_eval, p.Uab, p.ab, Pab, PPab);
  CalcPPPab(n_cvt, p.e_mode, HiHiHi_eval, p.Uab, p.ab, Pab, PPab, PPPab);

  double trace_HiKHiK = (to!double(ni_test) + trace_HiHi - 2 * trace_Hi) / (l * l);

  index_yy = GetabIndex(n_cvt + 2, n_cvt + 2, n_cvt);
  double P_yy = accessor(Pab, nc_total, index_yy);
  double PP_yy = accessor(PPab, nc_total, index_yy);
  double PPP_yy = accessor(PPPab, nc_total, index_yy);

  double yPKPy = (P_yy - PP_yy) / l;
  double yPKPKPy = (P_yy + PPP_yy - 2.0 * PP_yy) / (l * l);

  dev2 = 0.5 * trace_HiKHiK -
         0.5 * to!double(ni_test) * (2.0 * yPKPKPy * P_yy - yPKPy * yPKPy) /
             (P_yy * P_yy);

  return dev2;
}

extern(C) void LogL_dev12(double l, void *params, double *dev1, double *dev2) {

  auto ptr = cast(loglikeparam *)params;
  loglikeparam p = *ptr;

  size_t n_cvt = p.n_cvt;
  size_t ni_test = p.ni_test;
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  size_t nc_total;
  if (p.calc_null == true) {
    nc_total = n_cvt;
  } else {
    nc_total = n_cvt + 1;
  }

  double trace_Hi = 0.0, trace_HiHi = 0.0;
  size_t index_yy;

  DMatrix Pab;
  Pab.shape = [n_cvt + 2, n_index];

  DMatrix PPab;
  PPab.shape = [n_cvt + 2, n_index];

  DMatrix PPPab;
  PPab.shape = [n_cvt + 2, n_index];

  DMatrix Hi_eval;
  Hi_eval.shape = [1, p.eval.elements.length];
  DMatrix HiHi_eval;
  HiHi_eval.shape = [1, p.eval.elements.length];
  DMatrix HiHiHi_eval;
  HiHi_eval.shape = [1, p.eval.elements.length];
  DMatrix v_temp;
  v_temp.shape = [1, p.eval.elements.length];
  v_temp.elements = p.eval.elements;

  v_temp = multiply_dmatrix_num(v_temp, l);

  if (p.e_mode == 0) {
    //gsl_vector_set_all(Hi_eval, 1.0);
  } else {
    Hi_eval.elements = v_temp.elements.dup;
  }

  v_temp = add_dmatrix_num(v_temp, 1.0);
  Hi_eval = divide_dmatrix(Hi_eval, v_temp);

  HiHi_eval.elements = Hi_eval.elements.dup;
  HiHi_eval = slow_multiply_dmatrix(HiHi_eval, Hi_eval);
  HiHiHi_eval.elements = HiHi_eval.elements.dup;
  HiHiHi_eval = slow_multiply_dmatrix(HiHiHi_eval, Hi_eval);

  //gsl_vector_set_all(v_temp, 1.0);
  trace_Hi = matrix_mult(Hi_eval, v_temp).elements[0];
  trace_HiHi = matrix_mult(HiHi_eval, v_temp).elements[0];

  if (p.e_mode != 0) {
    trace_Hi = to!double(ni_test) - trace_Hi;
    trace_HiHi = 2 * trace_Hi + trace_HiHi - to!double(ni_test);
  }

  CalcPab(n_cvt, p.e_mode, Hi_eval, p.Uab, p.ab, Pab);
  CalcPPab(n_cvt, p.e_mode, HiHi_eval, p.Uab, p.ab, Pab, PPab);
  CalcPPPab(n_cvt, p.e_mode, HiHiHi_eval, p.Uab, p.ab, Pab, PPab, PPPab);

  double trace_HiK = (to!double(ni_test) - trace_Hi) / l;
  double trace_HiKHiK = (to!double(ni_test) + trace_HiHi - 2 * trace_Hi) / (l * l);

  index_yy = GetabIndex(n_cvt + 2, n_cvt + 2, n_cvt);

  double P_yy = accessor(Pab, nc_total, index_yy);
  double PP_yy = accessor(PPab, nc_total, index_yy);
  double PPP_yy = accessor(PPPab, nc_total, index_yy);

  double yPKPy = (P_yy - PP_yy) / l;
  double yPKPKPy = (P_yy + PPP_yy - 2.0 * PP_yy) / (l * l);

  *dev1 = -0.5 * trace_HiK + 0.5 * to!double(ni_test) * yPKPy / P_yy;
  *dev2 = 0.5 * trace_HiKHiK -
          0.5 * to!double(ni_test) * (2.0 * yPKPKPy * P_yy - yPKPy * yPKPy) /
              (P_yy * P_yy);

  return;
}

extern(C) void LogRL_dev12(double l, void* params, double* dev1, double* dev2) {
  auto ptr = cast(loglikeparam *)params;
  loglikeparam p = *ptr;

  size_t n_cvt = p.n_cvt;
  size_t ni_test = p.ni_test;
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  double df;
  size_t nc_total;
  if (p.calc_null == true) {
    nc_total = n_cvt;
    df = to!double(ni_test) - to!double(n_cvt);
  } else {
    nc_total = n_cvt + 1;
    df = to!double(ni_test) - to!double(n_cvt) - 1.0;
  }

  double trace_Hi = 0.0, trace_HiHi = 0.0;
  size_t index_ww;

  DMatrix Pab;
  Pab.shape = [n_cvt + 2, n_index];

  DMatrix PPab;
  PPab.shape = [n_cvt + 2, n_index];

  DMatrix PPPab;
  PPab.shape = [n_cvt + 2, n_index];

  DMatrix Hi_eval;
  Hi_eval.shape = [1, p.eval.elements.length];
  DMatrix HiHi_eval;
  HiHi_eval.shape = [1, p.eval.elements.length];
  DMatrix HiHiHi_eval;
  HiHi_eval.shape = [1, p.eval.elements.length];
  DMatrix v_temp;
  v_temp.shape = [1, p.eval.elements.length];
  v_temp.elements = p.eval.elements;

  v_temp = multiply_dmatrix_num(v_temp, l);

  if (p.e_mode == 0) {
    //gsl_vector_set_all(Hi_eval, 1.0);
  } else {
    Hi_eval.elements = v_temp.elements.dup;
  }
  v_temp = add_dmatrix_num(v_temp, 1.0);
  Hi_eval = divide_dmatrix(Hi_eval, v_temp);

  HiHi_eval.elements = Hi_eval.elements.dup;
  HiHi_eval = slow_multiply_dmatrix(HiHi_eval, Hi_eval);
  HiHiHi_eval.elements = HiHi_eval.elements.dup;
  HiHiHi_eval = slow_multiply_dmatrix(HiHiHi_eval, Hi_eval);

  //gsl_vector_set_all(v_temp, 1.0);
  trace_Hi = matrix_mult(Hi_eval, v_temp).elements[0];
  trace_HiHi = matrix_mult(HiHi_eval, v_temp).elements[0];

  if (p.e_mode != 0) {
    trace_Hi = to!double(ni_test) - trace_Hi;
    trace_HiHi = 2 * trace_Hi + trace_HiHi - to!double(ni_test);
  }

  CalcPab(n_cvt, p.e_mode, Hi_eval, p.Uab, p.ab, Pab);
  CalcPPab(n_cvt, p.e_mode, HiHi_eval, p.Uab, p.ab, Pab, PPab);
  CalcPPPab(n_cvt, p.e_mode, HiHiHi_eval, p.Uab, p.ab, Pab, PPab, PPPab);

  // Calculate tracePK and trace PKPK.
  double trace_P = trace_Hi, trace_PP = trace_HiHi;
  double ps_ww, ps2_ww, ps3_ww;
  for (size_t i = 0; i < nc_total; ++i) {
    index_ww = GetabIndex(i + 1, i + 1, n_cvt);
    ps_ww = accessor(Pab, i, index_ww);
    ps2_ww = accessor(PPab, i, index_ww);
    ps3_ww = accessor(PPPab, i, index_ww);
    trace_P -= ps2_ww / ps_ww;
    trace_PP += ps2_ww * ps2_ww / (ps_ww * ps_ww) - 2.0 * ps3_ww / ps_ww;
  }
  double trace_PK = (df - trace_P) / l;
  double trace_PKPK = (df + trace_PP - 2.0 * trace_P) / (l * l);

  // Calculate yPKPy, yPKPKPy.
  index_ww = GetabIndex(n_cvt + 2, n_cvt + 2, n_cvt);
  double P_yy = accessor(Pab, nc_total, index_ww);
  double PP_yy = accessor(PPab, nc_total, index_ww);
  double PPP_yy = accessor(PPPab, nc_total, index_ww);
  double yPKPy = (P_yy - PP_yy) / l;
  double yPKPKPy = (P_yy + PPP_yy - 2.0 * PP_yy) / (l * l);

  *dev1 = -0.5 * trace_PK + 0.5 * df * yPKPy / P_yy;
  *dev2 = 0.5 * trace_PKPK -
          0.5 * df * (2.0 * yPKPKPy * P_yy - yPKPy * yPKPy) / (P_yy * P_yy);

  return;
}

alias Tuple!(double,"l",double,"h") Lambda_tup;

void CalcLambda(const char func_name, void* params, const double l_min,
                const double l_max, const size_t n_region, double lambda,
                double logf) {
  if (func_name != 'R' && func_name != 'L' && func_name != 'r' &&
      func_name != 'l') {
    writeln("func_name only takes 'R' or 'L': 'R' for
            log-restricted likelihood, 'L' for log-likelihood.");
    return;
  }

  Lambda_tup[] lambda_lh;

  // Evaluate first-order derivates in different intervals.
  double lambda_l, lambda_h,
      lambda_interval = mlog(l_max / l_min) / to!double(n_region);
  double dev1_l, dev1_h, logf_l, logf_h;

  for (size_t i = 0; i < n_region; ++i) {
    lambda_l = l_min * exp(lambda_interval * i);
    lambda_h = l_min * exp(lambda_interval * (i + 1.0));

    if (func_name == 'R' || func_name == 'r') {
      dev1_l = LogRL_dev1(lambda_l, params);
      dev1_h = LogRL_dev1(lambda_h, params);
    } else {
      dev1_l = LogL_dev1(lambda_l, params);
      dev1_h = LogL_dev1(lambda_h, params);
    }

    if (dev1_l * dev1_h <= 0) {
      lambda_lh ~= Lambda_tup(lambda_l, lambda_h);
    }
  }

  // If derivates do not change signs in any interval.
  if (lambda_lh.length == 0) {
    if (func_name == 'R' || func_name == 'r') {
      logf_l = LogRL_f(l_min, params);
      logf_h = LogRL_f(l_max, params);
    } else {
      logf_l = LogL_f(l_min, params);
      logf_h = LogL_f(l_max, params);
    }

    if (logf_l >= logf_h) {
      lambda = l_min;
      logf = logf_l;
    } else {
      lambda = l_max;
      logf = logf_h;
    }
  } else {

    // If derivates change signs.
    int status;
    int iter = 0, max_iter = 100;
    double l, l_temp;

    gsl_function F;
    gsl_function_fdf FDF;

    F.params = params;
    FDF.params = params;

    if (func_name == 'R' || func_name == 'r') {
      F.function_ = &LogRL_dev1;
      FDF.f = &LogRL_dev1;
      FDF.df = &LogRL_dev2;
      FDF.fdf = &LogRL_dev12;
    } else {
      F.function_ = &LogL_dev1;
      FDF.f = &LogL_dev1;
      FDF.df = &LogL_dev2;
      FDF.fdf = &LogL_dev12;
    }

    gsl_root_fsolver_type *T_f;
    gsl_root_fsolver *s_f;
    T_f = cast(gsl_root_fsolver_type*)gsl_root_fsolver_brent;
    s_f = gsl_root_fsolver_alloc(T_f);

    gsl_root_fdfsolver_type *T_fdf;
    gsl_root_fdfsolver *s_fdf;
    T_fdf = cast(gsl_root_fdfsolver_type*)gsl_root_fdfsolver_newton;
    s_fdf = gsl_root_fdfsolver_alloc(T_fdf);

    for (int i = 0; i < lambda_lh.length; ++i) {
      lambda_l = lambda_lh[i].l;
      lambda_h = lambda_lh[i].h;
      gsl_root_fsolver_set(s_f, &F, lambda_l, lambda_h);

      do {
        iter++;
        status = gsl_root_fsolver_iterate(s_f);
        l = gsl_root_fsolver_root(s_f);
        lambda_l = gsl_root_fsolver_x_lower(s_f);
        lambda_h = gsl_root_fsolver_x_upper(s_f);
        status = gsl_root_test_interval(lambda_l, lambda_h, 0, 1e-1);
      } while (status == GSL_CONTINUE && iter < max_iter);

      iter = 0;

      gsl_root_fdfsolver_set(s_fdf, &FDF, l);

      do {
        iter++;
        status = gsl_root_fdfsolver_iterate(s_fdf);
        l_temp = l;
        l = gsl_root_fdfsolver_root(s_fdf);
        status = gsl_root_test_delta(l, l_temp, 0, 1e-5);
      } while (status == GSL_CONTINUE && iter < max_iter && l > l_min &&
               l < l_max);

      l = l_temp;
      if (l < l_min) {
        l = l_min;
      }
      if (l > l_max) {
        l = l_max;
      }
      if (func_name == 'R' || func_name == 'r') {
        logf_l = LogRL_f(l, &params);
      } else {
        logf_l = LogL_f(l, &params);
      }

      if (i == 0) {
        logf = logf_l;
        lambda = l;
      } else if (logf < logf_l) {
        logf = logf_l;
        lambda = l;
      } else {
      }
    }
    gsl_root_fsolver_free(s_f);
    gsl_root_fdfsolver_free(s_fdf);

    if (func_name == 'R' || func_name == 'r') {
      logf_l = LogRL_f(l_min, &params);
      logf_h = LogRL_f(l_max, &params);
    } else {
      logf_l = LogL_f(l_min, &params);
      logf_h = LogL_f(l_max, &params);
    }

    if (logf_l > logf) {
      lambda = l_min;
      logf = logf_l;
    }
    if (logf_h > logf) {
      lambda = l_max;
      logf = logf_h;
    }
  }

  return;
}

// Calculate lambda in the null model.
void CalcLambda(char func_name, DMatrix eval,
                DMatrix UtW, DMatrix Uty,
                double l_min, double l_max, size_t n_region,
                double lambda, double logl_H0) {
  if (func_name != 'R' && func_name != 'L' && func_name != 'r' &&
      func_name != 'l') {
    writeln("func_name only takes 'R' or 'L': 'R' for
           log-restricted likelihood, 'L' for log-likelihood.");
    return;
  }

  size_t n_cvt = UtW.shape[1], ni_test = UtW.shape[0];
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  DMatrix Uab;
  Uab.elements = [ni_test, n_index];

  DMatrix ab;
  ab.elements = [1, n_index];

  //gsl_matrix_set_zero(Uab);
  CalcUab(UtW, Uty, Uab);

  loglikeparam param0;
   //= loglikeparam(true, ni_test, n_cvt, eval, Uab, ab, 0);

  CalcLambda(func_name, cast(void *)&param0, l_min, l_max, n_region, lambda, logl_H0);

  return;
}

// ni_test is a LMM parameter
void CalcRLWald(size_t ni_test, double l, loglikeparam params, double beta,
                     double se, double p_wald) {
  size_t n_cvt = params.n_cvt;
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  int df = to!int(ni_test) - to!int(n_cvt) - 1;

  DMatrix Pab;
  Pab.shape = [n_cvt + 2, n_index];
  DMatrix Hi_eval;
  Hi_eval.shape = [1, params.eval.elements.length];
  DMatrix v_temp;
  v_temp.shape = [1, params.eval.elements.length];

  v_temp.elements = params.eval.elements;
  v_temp = multiply_dmatrix_num(v_temp, l);
  if (params.e_mode == 0) {
    //gsl_vector_set_all(Hi_eval, 1.0);
  } else {
    Hi_eval.elements = v_temp.elements.dup;
  }
  v_temp = add_dmatrix_num(v_temp, 1.0);
  Hi_eval = divide_dmatrix(Hi_eval, v_temp);

  CalcPab(n_cvt, params.e_mode, Hi_eval, params.Uab, params.ab, Pab);

  size_t index_yy = GetabIndex(n_cvt + 2, n_cvt + 2, n_cvt);
  size_t index_xx = GetabIndex(n_cvt + 1, n_cvt + 1, n_cvt);
  size_t index_xy = GetabIndex(n_cvt + 2, n_cvt + 1, n_cvt);
  double P_yy = accessor(Pab, n_cvt, index_yy);
  double P_xx = accessor(Pab, n_cvt, index_xx);
  double P_xy = accessor(Pab, n_cvt, index_xy);
  double Px_yy = accessor(Pab, n_cvt + 1, index_yy);

  beta = P_xy / P_xx;
  double tau = to!double(df) / Px_yy;
  se = sqrt(1.0 / (tau * P_xx));
  p_wald = gsl_cdf_fdist_Q((P_yy - Px_yy) * tau, 1.0, df);

  return;
}

void CalcRLScore(size_t ni_test, double l, loglikeparam params, double beta,
                      double se, double p_score) {
  size_t n_cvt = params.n_cvt;
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  int df = to!int(ni_test) - to!int(n_cvt) - 1;

  DMatrix Pab;
  Pab.shape = [n_cvt + 2, n_index];
  DMatrix Hi_eval;
  Hi_eval.shape = [1, params.eval.elements.length];
  DMatrix v_temp;
  v_temp.shape = [1, params.eval.elements.length];

  v_temp.elements = params.eval.elements;
  v_temp = multiply_dmatrix_num(v_temp, l);

  if (params.e_mode == 0) {
    //gsl_vector_set_all(Hi_eval, 1.0);
  } else {
    Hi_eval.elements = v_temp.elements.dup;
  }
  v_temp = add_dmatrix_num(v_temp, 1.0);
  Hi_eval = divide_dmatrix(Hi_eval, v_temp);

  CalcPab(n_cvt, params.e_mode, Hi_eval, params.Uab, params.ab, Pab);

  size_t index_yy = GetabIndex(n_cvt + 2, n_cvt + 2, n_cvt);
  size_t index_xx = GetabIndex(n_cvt + 1, n_cvt + 1, n_cvt);
  size_t index_xy = GetabIndex(n_cvt + 2, n_cvt + 1, n_cvt);
  double P_yy = accessor(Pab, n_cvt, index_yy);
  double P_xx = accessor(Pab, n_cvt, index_xx);
  double P_xy = accessor(Pab, n_cvt, index_xy);
  double Px_yy = accessor(Pab, n_cvt + 1, index_yy);

  beta = P_xy / P_xx;
  double tau = to!double(df) / Px_yy;
  se = sqrt(1.0 / (tau * P_xx));

  p_score =
      gsl_cdf_fdist_Q(to!double(ni_test) * P_xy * P_xy / (P_yy * P_xx), 1.0, df);

  return;
}

void CalcUab(DMatrix UtW, DMatrix Uty, DMatrix Uab) {
  size_t index_ab;
  size_t n_cvt = UtW.shape[1];

  DMatrix u_a;
  u_a.shape = [1, Uty.shape[1]];

  for (size_t a = 1; a <= n_cvt + 2; ++a) {
    if (a == n_cvt + 1) {
      continue;
    }

    if (a == n_cvt + 2) {
      u_a.elements = Uty.elements.dup;
    } else {
      DMatrix UtW_col = get_col(UtW, a - 1);
      u_a.elements = UtW_col.elements.dup;
    }

    for (size_t b = a; b >= 1; --b) {
      if (b == n_cvt + 1) {
        continue;
      }

      index_ab = GetabIndex(a, b, n_cvt);
      DMatrix Uab_col = get_col(Uab, index_ab);

      if (b == n_cvt + 2) {
        Uab_col.elements = Uty.elements.dup;
      } else {
        DMatrix UtW_col = get_col(UtW, b - 1);
        Uab_col.elements = UtW_col.elements.dup;
      }

      slow_multiply_dmatrix(Uab_col, u_a);
    }
  }
  return;
}

void CalcUab(DMatrix UtW, DMatrix Uty, DMatrix Utx, DMatrix Uab) {
  size_t index_ab;
  size_t n_cvt = UtW.shape[1];

  for (size_t b = 1; b <= n_cvt + 2; ++b) {
    index_ab = GetabIndex(n_cvt + 1, b, n_cvt);
    DMatrix Uab_col = get_col(Uab, index_ab);

    if (b == n_cvt + 2) {
      Uab_col.elements = Uty.elements;
    } else if (b == n_cvt + 1) {
      Uab_col.elements = Utx.elements;
    } else {
      DMatrix UtW_col = get_col(UtW, b - 1);
      Uab_col.elements = UtW_col.elements.dup;
    }

    slow_multiply_dmatrix(Uab_col, Utx);
  }

  return;
}

void Calcab(DMatrix W, DMatrix y, DMatrix ab) {
  size_t index_ab;
  size_t n_cvt = W.shape[1];

  double d;
  DMatrix v_a, v_b;
  v_a.shape = [1, y.shape[1]];
  v_b.shape = [1, y.shape[1]];

  for (size_t a = 1; a <= n_cvt + 2; ++a) {
    if (a == n_cvt + 1) {
      continue;
    }

    if (a == n_cvt + 2) {
      v_a.elements = y.elements.dup;
    } else {
      DMatrix W_col = get_col(W, a - 1);
      v_a.elements = W_col.elements.dup;
    }

    for (size_t b = a; b >= 1; --b) {
      if (b == n_cvt + 1) {
        continue;
      }

      index_ab = GetabIndex(a, b, n_cvt);

      if (b == n_cvt + 2) {
        v_b.elements = y.elements.dup;
      } else {
        DMatrix W_col = get_col(W, b - 1);
        v_b.elements = W_col.elements.dup;
      }

      d = matrix_mult(v_a.T, v_b).elements[0];
      ab.elements[index_ab] = d;
    }
  }

  return;
}

void Calcab(DMatrix W, DMatrix y, DMatrix x, DMatrix ab) {
  size_t index_ab;
  size_t n_cvt = W.shape[1];

  double d;
  DMatrix v_b;
  v_b.shape = [1, y.shape[1]];

  for (size_t b = 1; b <= n_cvt + 2; ++b) {
    index_ab = GetabIndex(n_cvt + 1, b, n_cvt);

    if (b == n_cvt + 2) {
      v_b.elements = y.elements.dup;
    } else if (b == n_cvt + 1) {
      v_b.elements = x.elements.dup;
    } else {
      DMatrix W_col = get_col(W, b - 1);
      v_b.elements = W_col.elements.dup;
    }

    d = matrix_mult(x.T, v_b).elements[0];
    ab.elements[index_ab] = d;
  }

  return;
}

// Obtain REML estimate for Vg and Ve using lambda_remle.
// Obtain beta and se(beta) for coefficients.
// ab is not used when e_mode==0.
void CalcLmmVgVeBeta(DMatrix eval, DMatrix UtW,
                     DMatrix Uty, double lambda, double vg,
                     double ve, DMatrix beta, DMatrix se_beta) {
  size_t n_cvt = UtW.shape[1], ni_test = UtW.shape[0];
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  DMatrix Uab;
  Uab.shape = [ni_test, n_index];

  DMatrix ab;
  ab.shape =[1, n_index];

  DMatrix Pab;
  Pab.shape = [n_cvt + 2, n_index];

  DMatrix Hi_eval;
  Hi_eval.shape =[1, eval.shape[1]];

  DMatrix v_temp;
  v_temp.shape =[1, eval.shape[1]];

  DMatrix HiW;
  HiW.shape = [eval.shape[1], UtW.shape[1]];

  DMatrix WHiW;
  WHiW.shape = [UtW.shape[1], UtW.shape[1]];

  DMatrix WHiy;
  WHiy.shape =[1, UtW.shape[1]];

  DMatrix Vbeta;
  Vbeta.shape = [UtW.shape[1], UtW.shape[1]];

  //gsl_matrix_set_zero(Uab);
  CalcUab(UtW, Uty, Uab);

  v_temp.elements = eval.elements;
  v_temp = multiply_dmatrix_num(v_temp, lambda);
  //gsl_vector_set_all(Hi_eval, 1.0);
  v_temp = add_dmatrix_num(v_temp, 1.0);
  Hi_eval = divide_dmatrix(Hi_eval, v_temp);

  // Calculate beta.
  HiW.elements = UtW.elements.dup;
  for (size_t i = 0; i < UtW.shape[1]; i++) {
    DMatrix HiW_col = get_col(HiW, i);
    HiW_col = slow_multiply_dmatrix(HiW_col, Hi_eval);
  }
  WHiW = matrix_mult(HiW, UtW);
  WHiy = matrix_mult(HiW, Uty);

  int sig;
  //gsl_permutation *pmt = gsl_permutation_alloc(UtW.shape[1]);
  //LUDecomp(WHiW, pmt, &sig);
  //LUSolve(WHiW, pmt, WHiy, beta);
  //LUInvert(WHiW, pmt, Vbeta);

  // Calculate vg and ve.
  CalcPab(n_cvt, 0, Hi_eval, Uab, ab, Pab);

  size_t index_yy = GetabIndex(n_cvt + 2, n_cvt + 2, n_cvt);
  double P_yy = accessor(Pab, n_cvt, index_yy);

  ve = P_yy / to!double(ni_test - n_cvt);
  vg = ve * lambda;

  // With ve, calculate se(beta).
  Vbeta = multiply_dmatrix_num(Vbeta, ve);

  // Obtain se_beta.
  for (size_t i = 0; i < Vbeta.shape[1]; i++) {
    se_beta.elements[i] = sqrt(accessor(Vbeta, i, i));
  }

  //gsl_permutation_free(pmt);
  return;
}

// Obtain REMLE estimate for PVE using lambda_remle.
void CalcPve(DMatrix eval, DMatrix UtW,
             DMatrix Uty, double lambda, double trace_G,
             double pve, double pve_se) {
  size_t n_cvt = UtW.shape[1], ni_test = UtW.shape[0];
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  DMatrix Uab;
  Uab.shape = [ni_test, n_index];
  DMatrix ab;
  ab.shape = [1, n_index];

  //gsl_matrix_set_zero(Uab);
  CalcUab(UtW, Uty, Uab);

  loglikeparam param0;
  //loglikeparam(true, ni_test, n_cvt, eval, Uab, ab, 0);
  //write constructor

  double se = sqrt(-1.0 / LogRL_dev2(lambda, &param0));

  pve = trace_G * lambda / (trace_G * lambda + 1.0);
  pve_se = trace_G / ((trace_G * lambda + 1.0) * (trace_G * lambda + 1.0)) * se;

  return;
}


struct GWAS_SNPs{
  bool size;
}

void AnalyzeBimbam(DMatrix U, DMatrix eval, DMatrix UtW, DMatrix Uty,
                        DMatrix W, DMatrix y, GWAS_SNPs gwasnps,
                        size_t n_cvt, size_t LMM_BATCH_SIZE) {


  // LOCO support
  bool process_gwasnps = gwasnps.size;
  if (process_gwasnps){
    writeln("AnalyzeBimbam w. LOCO");
  }

  // Calculate basic quantities.
  size_t n_index = (n_cvt + 2 + 1) * (n_cvt + 2) / 2;

  size_t inds = U.shape[0];
  DMatrix x;
  x.shape = [1, inds]; // #inds
  DMatrix x_miss;
  x_miss.shape = [1, inds];
  DMatrix Utx;
  Utx.shape = [1, U.shape[1]];
  DMatrix Uab;
  Uab.shape = [U.shape[1], n_index];
  DMatrix ab;
  ab.shape = [1, n_index];

  // Create a large matrix with LMM_BATCH_SIZE columns for batched processing
  // const size_t msize=(process_gwasnps ? 1 : LMM_BATCH_SIZE);
  size_t msize = LMM_BATCH_SIZE;
  DMatrix Xlarge;
  Xlarge.shape = [inds, msize];
  DMatrix UtXlarge;
  UtXlarge.shape = [inds, msize];

  //enforce_msg(Xlarge && UtXlarge, "Xlarge memory check"); // just to be sure
  //gsl_matrix_set_zero(Xlarge);
  //gsl_matrix_set_zero(Uab);
  CalcUab(UtW, Uty, Uab);

  // start reading genotypes and analyze
  size_t c = 0;

  //igzstream infile(file_geno.c_str(), igzstream::in);
  //enforce_msg(infile, "error reading genotype file");

  //auto batch_compute = [&](size_t l) { // using a C++ closure
  //  // Compute SNPs in batch, note the computations are independent per SNP
  //  gsl_matrix_view Xlarge_sub = gsl_matrix_submatrix(Xlarge, 0, 0, inds, l);
  //  gsl_matrix_view UtXlarge_sub =
  //      gsl_matrix_submatrix(UtXlarge, 0, 0, inds, l);

  //  time_start = clock();
  //  eigenlib_dgemm("T", "N", 1.0, U, &Xlarge_sub.matrix, 0.0,
  //                 &UtXlarge_sub.matrix);
  //  time_UtX += (clock() - time_start) / (double(CLOCKS_PER_SEC) * 60.0);

  //  gsl_matrix_set_zero(Xlarge);
  //  for (size_t i = 0; i < l; i++) {
  //    // for every batch...
  //    gsl_vector_view UtXlarge_col = gsl_matrix_column(UtXlarge, i);
  //    gsl_vector_memcpy(Utx, &UtXlarge_col.vector);

  //    CalcUab(UtW, Uty, Utx, Uab);

  //    time_start = clock();
  //    FUNC_PARAM param1 = {false, ni_test, n_cvt, eval, Uab, ab, 0};

  //    double lambda_mle = 0, lambda_remle = 0, beta = 0, se = 0, p_wald = 0;
  //    double p_lrt = 0, p_score = 0;
  //    double logl_H1 = 0.0;

  //    // 3 is before 1.
  //    if (a_mode == 3 || a_mode == 4) {
  //      CalcRLScore(l_mle_null, param1, beta, se, p_score);
  //    }

  //    if (a_mode == 1 || a_mode == 4) {
  //      // for univariate a_mode is 1
  //      CalcLambda('R', param1, l_min, l_max, n_region, lambda_remle, logl_H1);
  //      CalcRLWald(lambda_remle, param1, beta, se, p_wald);
  //    }

  //    if (a_mode == 2 || a_mode == 4) {
  //      CalcLambda('L', param1, l_min, l_max, n_region, lambda_mle, logl_H1);
  //      p_lrt = gsl_cdf_chisq_Q(2.0 * (logl_H1 - logl_mle_H0), 1);
  //    }

  //    time_opt += (clock() - time_start) / (double(CLOCKS_PER_SEC) * 60.0);

  //    // Store summary data.
  //    SUMSTAT SNPs = {beta,   se,    lambda_remle, lambda_mle,
  //                    p_wald, p_lrt, p_score};
  //    sumStat.push_back(SNPs);
  //  }
  //};

  //for (size_t t = 0; t < indicator_snp.size(); ++t) {
  //  // for every SNP
  //  string line;
  //  safeGetline(infile, line);
  //  if (t % d_pace == 0 || t == (ns_total - 1)) {
  //    ProgressBar("Reading SNPs  ", t, ns_total - 1);
  //  }
  //  if (indicator_snp[t] == 0)
  //    continue;

  //  char *ch_ptr = strtok((char *)line.c_str(), " , \t");
  //  auto snp = string(ch_ptr);
  //  // check whether SNP is included in gwasnps (used by LOCO)
  //  if (process_gwasnps && gwasnps.count(snp) == 0)
  //    continue;
  //  ch_ptr = strtok(NULL, " , \t");
  //  ch_ptr = strtok(NULL, " , \t");

  //  double x_mean = 0.0;
  //  int c_phen = 0;
  //  int n_miss = 0;
  //  gsl_vector_set_zero(x_miss);
  //  for (size_t i = 0; i < ni_total; ++i) {
  //    // get the genotypes per individual and compute stats per SNP
  //    ch_ptr = strtok(NULL, " , \t");
  //    if (indicator_idv[i] == 0)
  //      continue;

  //    if (strcmp(ch_ptr, "NA") == 0) {
  //      gsl_vector_set(x_miss, c_phen, 0.0);
  //      n_miss++;
  //    } else {
  //      double geno = atof(ch_ptr);

  //      gsl_vector_set(x, c_phen, geno);
  //      gsl_vector_set(x_miss, c_phen, 1.0);
  //      x_mean += geno;
  //    }
  //    c_phen++;
  //  }

  //  x_mean /= (double)(ni_test - n_miss);

  //  for (size_t i = 0; i < ni_test; ++i) {
  //    if (gsl_vector_get(x_miss, i) == 0) {
  //      gsl_vector_set(x, i, x_mean);
  //    }
  //  }
  //  // copy genotype values for SNP into Xlarge cache
  //  gsl_vector_view Xlarge_col = gsl_matrix_column(Xlarge, c % msize);
  //  gsl_vector_memcpy(&Xlarge_col.vector, x);
  //  c++; // count SNPs going in

  //  if (c == msize)
  //    batch_compute(msize);
  //}
  //batch_compute(c % msize);
  // cout << "Counted SNPs " << c << " sumStat " << sumStat.size() << endl;
  return;
}

unittest{
  size_t n_cvt;
  size_t e_mode;
  DMatrix Hi_eval = DMatrix([2,2],[1,2,3,4]);
  DMatrix Uab = DMatrix([2,2],[1,2,3,4]);
  DMatrix ab = DMatrix([2,2],[1,2,3,4]);
  DMatrix pab;

  CalcPab(n_cvt , e_mode,  Hi_eval, Uab,  ab, Pab));
  //assert();

  DMatrix PPab;
  DMatrix HiHiHi_eval;
  DMatrix PPab;
  CalcPPab(n_cvt, e_mode, HiHi_eval,  Uab, ab, Pab, PPab)
  //assert();

  DMatrix HiHiHi_eval;
  DMatrix PPPab;
  CalcPPPab( n_cvt, e_mode, HiHiHi_eval, Uab, ab, Pab, PPab, PPPab);
  //assert();

  size_t index = GetabIndex(size_t a, size_t b, size_t n_cvt);
  //assert( index == );

  char func_name = 'R';
  double l_min = 0;
  double l_max = 10;
  size_t n_region = 100;
  double lambda = 0.7;
  double logf;
  loglikeparam params;
  CalcLambda(func_name, cast(void *)&params, l_min, l_max, n_region, lambda, logf);
  //assert();

  // Calculate lambda in the null model.
  DMatrix eval;
  DMatrix Utw;
  DMatrix Uty;
  double  logl_H0;
  CalcLambda(func_name, eval, UtW, Uty, l_min, l_max, n_region, lambda, logl_H0);
  //assert();

  size_t ni_test = 1;
  double l = 6;
  double beta;
  double se;
  double p_wald;
  CalcRLWald(ni_test, l, params, beta, se, p_wald);
  //assert();

  double p_score;
  CalcRLScore(ni_test, l, params, beta, se, p_score);
  //assert();

  CalcUab(UtW, Uty, Uab);
  //assert();

  CalcUab(UtW, Uty, Utx, Uab);
  //assert();

  DMatrix W
  DMatrix y;
  Calcab(W, y, ab)
  //assert();

  DMatrix x;
  Calcab(W, y, x, ab)
  //assert();

  double vg, ve;
  DMatrix beta;
  DMatrix se_beta;
  CalcLmmVgVeBeta(eval, UtW, Uty, lambda, vg, ve, beta, se_beta);

  double trace_G, pve, pve_se;
  CalcPve(eval,  UtW, Uty, lambda, trace_G, pve,  pve_se);
}
