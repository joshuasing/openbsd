/*
 * Copyright 1995-2019 The OpenSSL Project Authors. All Rights Reserved.
 *
 * Licensed under the OpenSSL license (the "License").  You may not use
 * this file except in compliance with the License.  You can obtain a copy
 * in the file LICENSE in the source distribution or at
 * https://www.openssl.org/source/license.html
 */

#ifndef HEADER_CTERR_H
# define HEADER_CTERR_H

# include <openssl/opensslconf.h>

# ifndef OPENSSL_NO_CT

#ifdef  __cplusplus
extern "C"
#endif

int ERR_load_CT_strings(void);

/*
 * CT function codes.
 */
#  define CT_F_CTLOG_NEW                                   117
#  define CT_F_CTLOG_NEW_FROM_BASE64                       118
#  define CT_F_CTLOG_NEW_FROM_CONF                         119
#  define CT_F_CTLOG_STORE_LOAD_CTX_NEW                    122
#  define CT_F_CTLOG_STORE_LOAD_FILE                       123
#  define CT_F_CTLOG_STORE_LOAD_LOG                        130
#  define CT_F_CTLOG_STORE_NEW                             131
#  define CT_F_CT_BASE64_DECODE                            124
#  define CT_F_CT_POLICY_EVAL_CTX_NEW                      133
#  define CT_F_CT_V1_LOG_ID_FROM_PKEY                      125
#  define CT_F_I2O_SCT                                     107
#  define CT_F_I2O_SCT_LIST                                108
#  define CT_F_I2O_SCT_SIGNATURE                           109
#  define CT_F_O2I_SCT                                     110
#  define CT_F_O2I_SCT_LIST                                111
#  define CT_F_O2I_SCT_SIGNATURE                           112
#  define CT_F_SCT_CTX_NEW                                 126
#  define CT_F_SCT_CTX_VERIFY                              128
#  define CT_F_SCT_NEW                                     100
#  define CT_F_SCT_NEW_FROM_BASE64                         127
#  define CT_F_SCT_SET0_LOG_ID                             101
#  define CT_F_SCT_SET1_EXTENSIONS                         114
#  define CT_F_SCT_SET1_LOG_ID                             115
#  define CT_F_SCT_SET1_SIGNATURE                          116
#  define CT_F_SCT_SET_LOG_ENTRY_TYPE                      102
#  define CT_F_SCT_SET_SIGNATURE_NID                       103
#  define CT_F_SCT_SET_VERSION                             104

/*
 * CT reason codes.
 */
#  define CT_R_BASE64_DECODE_ERROR                         108
#  define CT_R_INVALID_LOG_ID_LENGTH                       100
#  define CT_R_LOG_CONF_INVALID                            109
#  define CT_R_LOG_CONF_INVALID_KEY                        110
#  define CT_R_LOG_CONF_MISSING_DESCRIPTION                111
#  define CT_R_LOG_CONF_MISSING_KEY                        112
#  define CT_R_LOG_KEY_INVALID                             113
#  define CT_R_SCT_FUTURE_TIMESTAMP                        116
#  define CT_R_SCT_INVALID                                 104
#  define CT_R_SCT_INVALID_SIGNATURE                       107
#  define CT_R_SCT_LIST_INVALID                            105
#  define CT_R_SCT_LOG_ID_MISMATCH                         114
#  define CT_R_SCT_NOT_SET                                 106
#  define CT_R_SCT_UNSUPPORTED_VERSION                     115
#  define CT_R_UNRECOGNIZED_SIGNATURE_NID                  101
#  define CT_R_UNSUPPORTED_ENTRY_TYPE                      102
#  define CT_R_UNSUPPORTED_VERSION                         103

# endif
#endif
