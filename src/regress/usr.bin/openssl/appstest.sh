#!/bin/sh
#
# $OpenBSD: appstest.sh,v 1.25 2019/11/03 02:09:35 inoguchi Exp $
#
# Copyright (c) 2016 Kinichiro Inoguchi <inoguchi@openbsd.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

#
# appstest.sh - test script for openssl command according to man OPENSSL(1)
#
# input  : none
# output : all files generated by this script go under $ssldir
#

function section_message {
	echo ""
	echo "#---------#---------#---------#---------#---------#---------#---------#--------"
	echo "==="
	echo "=== (Section) $1 `date +'%Y/%m/%d %H:%M:%S'`"
	echo "==="
}

function start_message {
	echo ""
	echo "[TEST] $1"
}

function stop_s_server {
	if [ ! -z "$s_server_pid" ] ; then
		echo ":-| stop s_server [ $s_server_pid ]"
		sleep 1
		kill -TERM $s_server_pid
		wait $s_server_pid
		s_server_pid=
	fi
}

function check_exit_status {
	status=$1
	if [ $status -ne 0 ] ; then
		stop_s_server
		echo ":-< error occurs, exit status = [ $status ]"
		exit $status
	else
		echo ":-) success. "
	fi
}

function usage {
	echo "usage: appstest.sh [-iq]"
}

function test_usage_lists_others {
	# === COMMAND USAGE ===
	section_message "COMMAND USAGE"
	
	start_message "output usages of all commands."
	
	cmds=`$openssl_bin list-standard-commands`
	$openssl_bin -help 2>> $user1_dir/usages.out
	for c in $cmds ; do
		$openssl_bin $c -help 2>> $user1_dir/usages.out
	done 
	
	start_message "check all list-* commands."
	
	lists=""
	lists="$lists list-standard-commands"
	lists="$lists list-message-digest-commands list-message-digest-algorithms"
	lists="$lists list-cipher-commands list-cipher-algorithms"
	lists="$lists list-public-key-algorithms"
	
	listsfile=$user1_dir/lists.out
	
	for l in $lists ; do
		echo "" >> $listsfile
		echo "$l" >> $listsfile
		$openssl_bin $l >> $listsfile
	done
	
	start_message "check interactive mode"
	$openssl_bin <<__EOF__
help
quit
__EOF__
	check_exit_status $?
	
	#---------#---------#---------#---------#---------#---------#---------
	
	# --- listing operations ---
	section_message "listing operations"
	
	start_message "ciphers"
	$openssl_bin ciphers -V
	check_exit_status $?
	
	start_message "errstr"
	$openssl_bin errstr 2606A074
	check_exit_status $?
	$openssl_bin errstr -stats 2606A074 > $user1_dir/errstr-stats.out
	check_exit_status $?
	
	#---------#---------#---------#---------#---------#---------#---------
	
	# --- random number etc. operations ---
	section_message "random number etc. operations"
	
	start_message "passwd"
	
	pass="test-pass-1234"
	
	echo $pass | $openssl_bin passwd -stdin -1
	check_exit_status $?
	
	echo $pass | $openssl_bin passwd -stdin -apr1
	check_exit_status $?
	
	echo $pass | $openssl_bin passwd -stdin -crypt
	check_exit_status $?
	
	start_message "prime"
	
	$openssl_bin prime 1
	check_exit_status $?
	
	$openssl_bin prime 2
	check_exit_status $?
	
	$openssl_bin prime -bits 64 -checks 3 -generate -hex -safe 5
	check_exit_status $?
	
	start_message "rand"
	
	$openssl_bin rand -base64 100
	check_exit_status $?
	
	$openssl_bin rand -hex 100
	check_exit_status $?
}

function test_md {
	# === MESSAGE DIGEST COMMANDS ===
	section_message "MESSAGE DIGEST COMMANDS"
	
	start_message "dgst - See [MESSAGE DIGEST COMMANDS] section."
	
	text="1234567890abcdefghijklmnopqrstuvwxyz"
	dgstdat=$user1_dir/dgst.dat
	echo $text > $dgstdat
	hmac_key="test-hmac-key"
	cmac_key="1234567890abcde1234567890abcde12"
	dgstkey=$user1_dir/dgstkey.pem
	dgstpass=test-dgst-pass
	dgstpub=$user1_dir/dgstpub.pem
	dgstsig=$user1_dir/dgst.sig

	$openssl_bin genrsa -aes256 -passout pass:$dgstpass -out $dgstkey
	check_exit_status $?
	
	$openssl_bin pkey -in $dgstkey -passin pass:$dgstpass -pubout \
		-out $dgstpub
	check_exit_status $?
	
	digests=`$openssl_bin list-message-digest-commands`
	
	for d in $digests ; do
	
		echo -n "$d ... "
		$openssl_bin dgst -$d -hex -out $dgstdat.$d $dgstdat
		check_exit_status $?
	
		echo -n "$d HMAC ... "
		$openssl_bin dgst -$d -c -hmac $hmac_key -out $dgstdat.$d.hmac \
			$dgstdat
		check_exit_status $?
	
		echo -n "$d CMAC ... "
		$openssl_bin dgst -$d -r -mac cmac -macopt cipher:aes-128-cbc \
			-macopt hexkey:$cmac_key -out $dgstdat.$d.cmac $dgstdat
		check_exit_status $?

		echo -n "$d sign ... "
		$openssl_bin dgst -sign $dgstkey -keyform pem \
			-sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:8 \
			-passin pass:$dgstpass -binary -out $dgstsig.$d $dgstdat
		check_exit_status $?

		echo -n "$d verify ... "
		$openssl_bin dgst -verify $dgstpub \
			-sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:8 \
			-signature $dgstsig.$d $dgstdat
		check_exit_status $?

		echo -n "$d prverify ... "
		$openssl_bin dgst -prverify $dgstkey -passin pass:$dgstpass \
			-sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:8 \
			-signature $dgstsig.$d $dgstdat
		check_exit_status $?
	done
}

function test_encoding_cipher {
	# === ENCODING AND CIPHER COMMANDS ===
	section_message "ENCODING AND CIPHER COMMANDS"
	
	start_message "enc - See [ENCODING AND CIPHER COMMANDS] section."
	
	text="1234567890abcdefghijklmnopqrstuvwxyz"
	encfile=$user1_dir/encfile.dat
	echo $text > $encfile
	pass="test-pass-1234"
	
	ciphers=`$openssl_bin list-cipher-commands`
	
	for c in $ciphers ; do
		echo -n "$c ... encoding ... "
		$openssl_bin enc -$c -e -base64 -pass pass:$pass \
			-in $encfile -out $encfile-$c.enc
		check_exit_status $?
	
		echo -n "decoding ... "
		$openssl_bin enc -$c -d -base64 -pass pass:$pass \
			-in $encfile-$c.enc -out $encfile-$c.dec
		check_exit_status $?
	
		echo -n "cmp ... "
		cmp $encfile $encfile-$c.dec
		check_exit_status $?
	done
}

function test_key {
	# === various KEY operations ===
	section_message "various KEY operations"
	
	key_pass=test-key-pass
	
	# DH
	
	start_message "gendh - Obsoleted by dhparam."
	gendh2=$key_dir/gendh2.pem
	$openssl_bin gendh -2 -out $gendh2
	check_exit_status $?
	
	start_message "dh - Obsoleted by dhparam."
	$openssl_bin dh -in $gendh2 -check -text -out $gendh2.out
	check_exit_status $?
	
	if [ $no_long_tests = 0 ] ; then
		start_message "dhparam - Superseded by genpkey and pkeyparam."
		dhparam2=$key_dir/dhparam2.pem
		$openssl_bin dhparam -2 -out $dhparam2
		check_exit_status $?
		$openssl_bin dhparam -in $dhparam2 -check -text \
			-out $dhparam2.out
		check_exit_status $?
	else
		start_message "SKIPPING dhparam - Superseded by genpkey and pkeyparam. (quick mode)"
	fi
	
	# DSA
	
	start_message "dsaparam - Superseded by genpkey and pkeyparam."
	dsaparam512=$key_dir/dsaparam512.pem
	$openssl_bin dsaparam -genkey -out $dsaparam512 512
	check_exit_status $?
	
	start_message "dsa"
	$openssl_bin dsa -in $dsaparam512 -text -modulus -out $dsaparam512.out
	check_exit_status $?
	
	start_message "gendsa - Superseded by genpkey and pkey."
	gendsa_des3=$key_dir/gendsa_des3.pem
	$openssl_bin gendsa -des3 -out $gendsa_des3 \
		-passout pass:$key_pass $dsaparam512
	check_exit_status $?
	
	# RSA
	
	start_message "genrsa - Superseded by genpkey."
	genrsa_aes256=$key_dir/genrsa_aes256.pem
	$openssl_bin genrsa -f4 -aes256 -out $genrsa_aes256 \
		-passout pass:$key_pass 2048
	check_exit_status $?
	
	start_message "rsa"
	$openssl_bin rsa -in $genrsa_aes256 -passin pass:$key_pass \
		-check -text -out $genrsa_aes256.out
	check_exit_status $?
	
	start_message "rsautl - Superseded by pkeyutl."
	rsautldat=$key_dir/rsautl.dat
	rsautlsig=$key_dir/rsautl.sig
	echo "abcdefghijklmnopqrstuvwxyz1234567890" > $rsautldat
	
	$openssl_bin rsautl -sign -in $rsautldat -inkey $genrsa_aes256 \
		-passin pass:$key_pass -out $rsautlsig
	check_exit_status $?
	
	$openssl_bin rsautl -verify -in $rsautlsig -inkey $genrsa_aes256 \
		-passin pass:$key_pass
	check_exit_status $?
	
	# EC
	
	start_message "ecparam -list-curves"
	$openssl_bin ecparam -list_curves
	check_exit_status $?
	
	# get all EC curves
	ec_curves=`$openssl_bin ecparam -list_curves | grep ':' | cut -d ':' -f 1`
	
	start_message "ecparam and ec"
	
	for curve in $ec_curves ;
	do
		ecparam=$key_dir/ecparam_$curve.pem
	
		echo -n "ec - $curve ... ecparam ... "
		$openssl_bin ecparam -out $ecparam -name $curve -genkey \
			-param_enc explicit -conv_form compressed -C
		check_exit_status $?
	
		echo -n "ec ... "
		$openssl_bin ec -in $ecparam -text \
			-out $ecparam.out 2> /dev/null
		check_exit_status $?
	done
	
	# PKEY
	
	start_message "genpkey"
	
	# DH by GENPKEY
	
	genpkey_dh_param=$key_dir/genpkey_dh_param.pem
	$openssl_bin genpkey -genparam -algorithm DH -out $genpkey_dh_param \
		-pkeyopt dh_paramgen_prime_len:1024
	check_exit_status $?
	
	genpkey_dh=$key_dir/genpkey_dh.pem
	$openssl_bin genpkey -paramfile $genpkey_dh_param -out $genpkey_dh
	check_exit_status $?
	
	# DSA by GENPKEY
	
	genpkey_dsa_param=$key_dir/genpkey_dsa_param.pem
	$openssl_bin genpkey -genparam -algorithm DSA -out $genpkey_dsa_param \
		-pkeyopt dsa_paramgen_bits:1024
	check_exit_status $?
	
	genpkey_dsa=$key_dir/genpkey_dsa.pem
	$openssl_bin genpkey -paramfile $genpkey_dsa_param -out $genpkey_dsa
	check_exit_status $?
	
	# RSA by GENPKEY
	
	genpkey_rsa=$key_dir/genpkey_rsa.pem
	$openssl_bin genpkey -algorithm RSA -out $genpkey_rsa \
		-pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:3
	check_exit_status $?
	
	genpkey_rsa_pss=$key_dir/genpkey_rsa_pss.pem
	$openssl_bin genpkey -algorithm RSA-PSS -out $genpkey_rsa_pss \
		-pkeyopt rsa_keygen_bits:2048 \
		-pkeyopt rsa_pss_keygen_mgf1_md:sha256 \
		-pkeyopt rsa_pss_keygen_md:sha256 \
		-pkeyopt rsa_pss_keygen_saltlen:32
	check_exit_status $?
	
	# EC by GENPKEY
	
	genpkey_ec_param=$key_dir/genpkey_ec_param.pem
	$openssl_bin genpkey -genparam -algorithm EC -out $genpkey_ec_param \
		-pkeyopt ec_paramgen_curve:secp384r1
	check_exit_status $?
	
	genpkey_ec=$key_dir/genpkey_ec.pem
	$openssl_bin genpkey -paramfile $genpkey_ec_param -out $genpkey_ec
	check_exit_status $?
	
	genpkey_ec_2=$key_dir/genpkey_ec_2.pem
	$openssl_bin genpkey -paramfile $genpkey_ec_param -out $genpkey_ec_2
	check_exit_status $?
	
	start_message "pkeyparam"
	
	$openssl_bin pkeyparam -in $genpkey_dh_param -text \
		-out $genpkey_dh_param.out
	check_exit_status $?
	
	$openssl_bin pkeyparam -in $genpkey_dsa_param -text \
		-out $genpkey_dsa_param.out
	check_exit_status $?
	
	$openssl_bin pkeyparam -in $genpkey_ec_param -text \
		-out $genpkey_ec_param.out
	check_exit_status $?
	
	start_message "pkey"
	
	$openssl_bin pkey -in $genpkey_dh -pubout -out $genpkey_dh.pub \
		-text_pub
	check_exit_status $?
	
	$openssl_bin pkey -in $genpkey_dsa -pubout -out $genpkey_dsa.pub \
		-text_pub
	check_exit_status $?
	
	$openssl_bin pkey -in $genpkey_rsa -pubout -out $genpkey_rsa.pub \
		-text_pub
	check_exit_status $?
	
	$openssl_bin pkey -in $genpkey_ec -pubout -out $genpkey_ec.pub \
		-text_pub
	check_exit_status $?
	
	$openssl_bin pkey -in $genpkey_ec_2 -pubout -out $genpkey_ec_2.pub \
		-text_pub
	check_exit_status $?
	
	start_message "pkeyutl"
	
	pkeyutldat=$key_dir/pkeyutl.dat
	pkeyutlsig=$key_dir/pkeyutl.sig
	echo "abcdefghijklmnopqrstuvwxyz1234567890" > $pkeyutldat
	
	$openssl_bin pkeyutl -sign -in $pkeyutldat -inkey $genpkey_rsa \
		-out $pkeyutlsig
	check_exit_status $?
	
	$openssl_bin pkeyutl -verify -in $pkeyutldat -sigfile $pkeyutlsig \
		-inkey $genpkey_rsa
	check_exit_status $?
	
	$openssl_bin pkeyutl -verifyrecover -in $pkeyutlsig -inkey $genpkey_rsa
	check_exit_status $?

	pkeyutlenc=$key_dir/pkeyutl.enc
	pkeyutldec=$key_dir/pkeyutl.dec

	$openssl_bin pkeyutl -encrypt -in $pkeyutldat \
		-pubin -inkey $genpkey_rsa.pub -out $pkeyutlenc
	check_exit_status $?

	$openssl_bin pkeyutl -decrypt -in $pkeyutlenc \
		-inkey $genpkey_rsa -out $pkeyutldec
	check_exit_status $?

	diff $pkeyutldat $pkeyutldec
	check_exit_status $?

	pkeyutl_rsa_oaep_enc=$key_dir/pkeyutl_rsa_oaep.enc
	pkeyutl_rsa_oaep_dec=$key_dir/pkeyutl_rsa_oaep.dec

	$openssl_bin pkeyutl -encrypt -in $pkeyutldat \
		-inkey $genpkey_rsa \
		-pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 \
		-pkeyopt rsa_oaep_label:0011223344556677 \
		-out $pkeyutl_rsa_oaep_enc
	check_exit_status $?

	$openssl_bin pkeyutl -decrypt -in $pkeyutl_rsa_oaep_enc \
		-inkey $genpkey_rsa \
		-pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 \
		-pkeyopt rsa_oaep_label:0011223344556677 \
		-out $pkeyutl_rsa_oaep_dec
	check_exit_status $?

	diff $pkeyutldat $pkeyutl_rsa_oaep_dec
	check_exit_status $?

	pkeyutlsc1=$key_dir/pkeyutl.sc1
	pkeyutlsc2=$key_dir/pkeyutl.sc2

	$openssl_bin pkeyutl -derive -inkey $genpkey_ec \
		-peerkey $genpkey_ec_2.pub -out $pkeyutlsc1 -hexdump
	check_exit_status $?

	$openssl_bin pkeyutl -derive -inkey $genpkey_ec_2 \
		-peerkey $genpkey_ec.pub -out $pkeyutlsc2 -hexdump
	check_exit_status $?

	diff $pkeyutlsc1 $pkeyutlsc2
	check_exit_status $?
}

function test_pki {
	section_message "setup local CA"

	#
	# prepare test openssl.cnf
	#

	cat << __EOF__ > $ssldir/openssl.cnf
oid_section = new_oids
[ new_oids ]
tsa_policy1 = 1.2.3.4.1
tsa_policy2 = 1.2.3.4.5.6
tsa_policy3 = 1.2.3.4.5.7
[ ca ]
default_ca    = CA_default
[ CA_default ]
dir           = ./$ca_dir
crl_dir       = \$dir/crl
database      = \$dir/index.txt
new_certs_dir = \$dir/newcerts
serial        = \$dir/serial
crlnumber     = \$dir/crlnumber
default_days  = 1
default_md    = default
policy        = policy_match
[ policy_match ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional
[ req ]
distinguished_name      = req_distinguished_name 
[ req_distinguished_name ]
countryName                     = Country Name
countryName_default             = JP
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = State or Province Name
stateOrProvinceName_default     = Tokyo
organizationName                = Organization Name
organizationName_default        = TEST_DUMMY_COMPANY
commonName                      = Common Name
[ tsa ]
default_tsa   = tsa_config1 
[ tsa_config1 ]
dir           = ./$tsa_dir
serial        = \$dir/serial
crypto_device = builtin
digests       = sha1, sha256, sha384, sha512
default_policy = tsa_policy1
other_policies = tsa_policy2, tsa_policy3
[ tsa_ext ]
keyUsage = critical,nonRepudiation
extendedKeyUsage = critical,timeStamping
[ ocsp_ext ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation,digitalSignature,keyEncipherment
extendedKeyUsage = OCSPSigning
__EOF__

	#---------#---------#---------#---------#---------#---------#---------
	
	#
	# setup test CA
	#
	
	mkdir -p $ca_dir
	mkdir -p $tsa_dir
	mkdir -p $ocsp_dir
	mkdir -p $server_dir
	
	mkdir -p $ca_dir/certs
	mkdir -p $ca_dir/private
	mkdir -p $ca_dir/crl
	mkdir -p $ca_dir/newcerts
	chmod 700 $ca_dir/private
	echo "01" > $ca_dir/serial
	touch $ca_dir/index.txt 
	touch $ca_dir/crlnumber
	echo "01" > $ca_dir/crlnumber
	
	# 
	# setup test TSA 
	#
	mkdir -p $tsa_dir/private
	chmod 700 $tsa_dir/private
	echo "01" > $tsa_dir/serial
	touch $tsa_dir/index.txt 
	
	# 
	# setup test OCSP 
	#
	mkdir -p $ocsp_dir/private
	chmod 700 $ocsp_dir/private
	
	#---------#---------#---------#---------#---------#---------#---------
	
	# --- CA initiate (generate CA key and cert) --- 
	
	start_message "req ... generate CA key and self signed cert"
	
	ca_cert=$ca_dir/ca_cert.pem 
	ca_key=$ca_dir/private/ca_key.pem ca_pass=test-ca-pass 
	
	if [ $mingw = 0 ] ; then
		subj='/C=JP/ST=Tokyo/O=TEST_DUMMY_COMPANY/CN=testCA.test_dummy.com/'
	else
		subj='//C=JP\ST=Tokyo\O=TEST_DUMMY_COMPANY\CN=testCA.test_dummy.com\'
	fi
	
	$openssl_bin req -new -x509 -batch -newkey rsa:2048 \
		-pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:3 \
		-sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:8 \
		-config $ssldir/openssl.cnf -verbose \
		-subj $subj -days 1 -set_serial 1 -multivalue-rdn \
		-keyout $ca_key -passout pass:$ca_pass \
		-out $ca_cert -outform pem
	check_exit_status $?
	
	#---------#---------#---------#---------#---------#---------#---------
	
	# --- TSA initiate (generate TSA key and cert) ---
	
	start_message "req ... generate TSA key and cert"
	
	# generate CSR for TSA
	
	tsa_csr=$tsa_dir/tsa_csr.pem
	tsa_key=$tsa_dir/private/tsa_key.pem
	tsa_pass=test-tsa-pass
	
	if [ $mingw = 0 ] ; then
		subj='/C=JP/ST=Tokyo/O=TEST_DUMMY_COMPANY/CN=testTSA.test_dummy.com/'
	else
		subj='//C=JP\ST=Tokyo\O=TEST_DUMMY_COMPANY\CN=testTSA.test_dummy.com\'
	fi
	
	$openssl_bin req -new -keyout $tsa_key -out $tsa_csr \
		-passout pass:$tsa_pass -subj $subj -asn1-kludge
	check_exit_status $?
	
	start_message "ca ... sign by CA with TSA extensions"
	
	tsa_cert=$tsa_dir/tsa_cert.pem
	
	$openssl_bin ca -batch -cert $ca_cert -keyfile $ca_key -keyform pem \
		-key $ca_pass -config $ssldir/openssl.cnf -create_serial \
		-policy policy_match -days 1 -md sha256 -extensions tsa_ext \
		-sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:32 \
		-multivalue-rdn -preserveDN -noemailDN \
		-in $tsa_csr -outdir $tsa_dir -out $tsa_cert -verbose -notext
	check_exit_status $?
	
	#---------#---------#---------#---------#---------#---------#---------
	
	# --- OCSP initiate (generate OCSP key and cert) ---
	
	start_message "req ... generate OCSP key and cert"
	
	# generate CSR for OCSP 
	
	ocsp_csr=$ocsp_dir/ocsp_csr.pem
	ocsp_key=$ocsp_dir/private/ocsp_key.pem
	
	if [ $mingw = 0 ] ; then
		subj='/C=JP/ST=Tokyo/O=TEST_DUMMY_COMPANY/CN=testOCSP.test_dummy.com/'
	else
		subj='//C=JP\ST=Tokyo\O=TEST_DUMMY_COMPANY\CN=testOCSP.test_dummy.com\'
	fi
	
	$openssl_bin req -new -keyout $ocsp_key -nodes -out $ocsp_csr \
		-subj $subj -no-asn1-kludge
	check_exit_status $?
	
	start_message "ca ... sign by CA with OCSP extensions"
	
	ocsp_cert=$ocsp_dir/ocsp_cert.pem
	
	$openssl_bin ca -batch -cert $ca_cert -keyfile $ca_key -keyform pem \
		-key $ca_pass -out $ocsp_cert -extensions ocsp_ext \
		-startdate `date -u '+%y%m%d%H%M%SZ'` -enddate 491223235959Z \
		-subj $subj -infiles $ocsp_csr 
	check_exit_status $?
	
	#---------#---------#---------#---------#---------#---------#---------
	
	# --- server-admin operations (generate server key and csr) ---
	section_message "server-admin operations (generate server key and csr)"
	
	server_key=$server_dir/server_key.pem
	server_csr=$server_dir/server_csr.pem
	server_pass=test-server-pass
	
	if [ $mingw = 0 ] ; then
		subj='/C=JP/ST=Tokyo/O=TEST_DUMMY_COMPANY/CN=localhost.test_dummy.com/'
	else
		subj='//C=JP\ST=Tokyo\O=TEST_DUMMY_COMPANY\CN=localhost.test_dummy.com\'
	fi
	
	start_message "genrsa ... generate server key#1"

	$openssl_bin genrsa -aes256 -passout pass:$server_pass -out $server_key
	check_exit_status $?

	start_message "req ... generate server csr#1"

	$openssl_bin req -new -subj $subj -sha256 \
		-key $server_key -keyform pem -passin pass:$server_pass \
		-out $server_csr -outform pem
	check_exit_status $?
	
	start_message "req ... verify server csr#1"

	$openssl_bin req -verify -in $server_csr -inform pem \
		-newhdr -noout -pubkey -subject -modulus -text \
		-nameopt multiline -reqopt compatible \
		-out $server_csr.verify.out
	check_exit_status $?

	start_message "req ... generate server csr#2 (interactive mode)"
	
	revoke_key=$server_dir/revoke_key.pem
	revoke_csr=$server_dir/revoke_csr.pem
	revoke_pass=test-revoke-pass

	$openssl_bin req -new -keyout $revoke_key -out $revoke_csr \
		-passout pass:$revoke_pass <<__EOF__
JP
Tokyo
TEST_DUMMY_COMPANY
revoke.test_dummy.com
__EOF__
	check_exit_status $?

	#---------#---------#---------#---------#---------#---------#---------
	
	# --- CA operations (issue cert for server) ---
	section_message "CA operations (issue cert for server)"
	
	start_message "ca ... issue cert for server csr#1"
	
	server_cert=$server_dir/server_cert.pem
	$openssl_bin ca -batch -cert $ca_cert -keyfile $ca_key -key $ca_pass \
		-in $server_csr -out $server_cert
	check_exit_status $?
	
	start_message "x509 ... issue cert for server csr#2"
	
	revoke_cert=$server_dir/revoke_cert.pem
	$openssl_bin x509 -req -in $revoke_csr -CA $ca_cert -CAform pem \
		-CAkey $ca_key -CAkeyform pem \
		-CAserial $ca_dir/serial -set_serial 10 \
		-passin pass:$ca_pass -CAcreateserial -out $revoke_cert
	check_exit_status $?
	
	#---------#---------#---------#---------#---------#---------#---------
	
	# --- CA operations (revoke cert and generate crl) ---
	section_message "CA operations (revoke cert and generate crl)"
	
	start_message "ca ... revoke server cert#2"
	crl_file=$ca_dir/crl.pem
	$openssl_bin ca -gencrl -out $crl_file -revoke $revoke_cert \
		-config $ssldir/openssl.cnf -name CA_default \
		-crldays 30 -crlhours 12 -crlsec 30 -updatedb \
		-crl_reason unspecified -crl_hold 1.2.840.10040.2.2 \
		-crl_compromise `date -u '+%Y%m%d%H%M%SZ'` \
		-crl_CA_compromise `date -u '+%Y%m%d%H%M%SZ'` \
		-keyfile $ca_key -passin pass:$ca_pass -cert $ca_cert
	check_exit_status $?
	
	start_message "ca ... show certificate status by serial number"
	$openssl_bin ca -config $ssldir/openssl.cnf -status 1

	start_message "crl ... CA generates CRL"
	$openssl_bin crl -in $crl_file -fingerprint
	check_exit_status $?
	
	crl_p7=$ca_dir/crl.p7
	start_message "crl2pkcs7 ... convert CRL to pkcs7"
	$openssl_bin crl2pkcs7 -in $crl_file -certfile $ca_cert -out $crl_p7
	check_exit_status $?
	
	#---------#---------#---------#---------#---------#---------#---------
	
	# --- server-admin operations (check csr, verify cert, certhash) ---
	section_message "server-admin operations (check csr, verify cert, certhash)"
	
	start_message "asn1parse ... parse server csr#1"
	$openssl_bin asn1parse -in $server_csr -i -dlimit 100 -length 1000 \
		-strparse 01 > $server_csr.asn1parse.out
	check_exit_status $?
	
	start_message "verify ... server cert#1"
	$openssl_bin verify -verbose -CAfile $ca_cert -CRLfile $crl_file \
	       	-crl_check -issuer_checks -purpose sslserver $server_cert
	check_exit_status $?
	
	start_message "x509 ... get detail info about server cert#1"
	$openssl_bin x509 -in $server_cert -text -C -dates -startdate -enddate \
		-fingerprint -issuer -issuer_hash -issuer_hash_old \
		-subject -hash -subject_hash -subject_hash_old -ocsp_uri \
		-ocspid -modulus -pubkey -serial -email -noout -trustout \
		-alias -clrtrust -clrreject -next_serial -checkend 3600 \
		-nameopt multiline -certopt compatible > $server_cert.x509.out
	check_exit_status $?
	
	if [ $mingw = 0 ] ; then
		start_message "certhash"
		$openssl_bin certhash -v $server_dir
		check_exit_status $?
	fi
	
	# self signed
	start_message "x509 ... generate self signed server cert"
	server_self_cert=$server_dir/server_self_cert.pem
	$openssl_bin x509 -in $server_cert -signkey $server_key -keyform pem \
		-sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:8 \
		-passin pass:$server_pass -out $server_self_cert -days 1
	check_exit_status $?
	
	#---------#---------#---------#---------#---------#---------#---------
	
	# --- Netscape SPKAC operations ---
	section_message "Netscape SPKAC operations"
	
	# server-admin generates SPKAC
	
	start_message "spkac"
	spkacfile=$server_dir/spkac.file
	
	$openssl_bin spkac -key $genpkey_rsa -challenge hello -out $spkacfile
	check_exit_status $?
	
	$openssl_bin spkac -in $spkacfile -verify -out $spkacfile.out
	check_exit_status $?
	
	spkacreq=$server_dir/spkac.req
	cat << __EOF__ > $spkacreq
countryName = JP
stateOrProvinceName = Tokyo
organizationName = TEST_DUMMY_COMPANY
commonName = spkac.test_dummy.com
__EOF__
	cat $spkacfile >> $spkacreq
	
	# CA signs SPKAC
	start_message "ca ... CA signs SPKAC csr"
	spkaccert=$server_dir/spkac.cert
	$openssl_bin ca -batch -cert $ca_cert -keyfile $ca_key -key $ca_pass \
		-spkac $spkacreq -out $spkaccert
	check_exit_status $?
	
	start_message "x509 ... convert DER format SPKAC cert to PEM"
	spkacpem=$server_dir/spkac.pem
	$openssl_bin x509 -in $spkaccert -inform DER -out $spkacpem -outform PEM
	check_exit_status $?
	
	# server-admin cert verify
	
	start_message "nseq"
	$openssl_bin nseq -in $spkacpem -toseq -out $spkacpem.nseq
	check_exit_status $?
	
	#---------#---------#---------#---------#---------#---------#---------
	
	# --- user1 operations (generate user1 key and csr) ---
	section_message "user1 operations (generate user1 key and csr)"
	
	# trust
	start_message "x509 ... trust testCA cert"
	user1_trust=$user1_dir/user1_trust_ca.pem
	$openssl_bin x509 -in $ca_cert -addtrust clientAuth \
		-setalias "trusted testCA" -purpose -out $user1_trust
	check_exit_status $?
	
	start_message "req ... generate private key and csr for user1"
	
	user1_key=$user1_dir/user1_key.pem
	user1_csr=$user1_dir/user1_csr.pem
	user1_pass=test-user1-pass
	
	if [ $mingw = 0 ] ; then
		subj='/C=JP/ST=Tokyo/O=TEST_DUMMY_COMPANY/CN=user1.test_dummy.com/'
	else
		subj='//C=JP\ST=Tokyo\O=TEST_DUMMY_COMPANY\CN=user1.test_dummy.com\'
	fi
	
	$openssl_bin req -new -keyout $user1_key -out $user1_csr \
		-passout pass:$user1_pass -subj $subj
	check_exit_status $?
	
	#---------#---------#---------#---------#---------#---------#---------
	
	# --- CA operations (issue cert for user1) ---
	section_message "CA operations (issue cert for user1)"
	
	start_message "ca ... issue cert for user1"
	
	user1_cert=$user1_dir/user1_cert.pem
	$openssl_bin ca -batch -cert $ca_cert -keyfile $ca_key -key $ca_pass \
		-in $user1_csr -out $user1_cert
	check_exit_status $?
}

function test_tsa {
	# --- TSA operations ---
	section_message "TSA operations"
	
	tsa_dat=$user1_dir/tsa.dat
	cat << __EOF__ > $tsa_dat
Hello Bob,
Sincerely yours
Alice
__EOF__

	# Query
	start_message "ts ... create time stamp request"
	
	tsa_tsq=$user1_dir/tsa.tsq
	
	$openssl_bin ts -query -sha1 -data $tsa_dat -no_nonce -out $tsa_tsq
	check_exit_status $?
	
	start_message "ts ... print time stamp request"
	
	$openssl_bin ts -query -in $tsa_tsq -text
	check_exit_status $?
	
	# Reply
	start_message "ts ... create time stamp response for a request"
	
	tsa_tsr=$user1_dir/tsa.tsr
	
	$openssl_bin ts -reply -queryfile $tsa_tsq -inkey $tsa_key \
		-passin pass:$tsa_pass -signer $tsa_cert -chain $ca_cert \
		-config $ssldir/openssl.cnf -section tsa_config1 -cert \
		-policy 1.3.6.1.4.1.4146.2.3 -out $tsa_tsr
	check_exit_status $?
	
	# Verify
	start_message "ts ... verify time stamp response"
	
	$openssl_bin ts -verify -queryfile $tsa_tsq -in $tsa_tsr \
		-CAfile $ca_cert -untrusted $tsa_cert
	check_exit_status $?
}

function test_smime {
	# --- S/MIME operations ---
	section_message "S/MIME operations"
	
	smime_txt=$user1_dir/smime.txt
	smime_enc=$user1_dir/smime.enc
	smime_sig=$user1_dir/smime.sig
	smime_p7o=$user1_dir/smime.p7o
	smime_sgr=$user1_dir/smime.sgr
	smime_ver=$user1_dir/smime.ver
	smime_dec=$user1_dir/smime.dec
	
	cat << __EOF__ > $smime_txt
Hello Bob,
Sincerely yours
Alice
__EOF__
	
	# encrypt
	start_message "smime ... encrypt message"

	$openssl_bin smime -encrypt -aes256 -binary -in $smime_txt \
		-out $smime_enc $server_cert
	check_exit_status $?

	# sign
	start_message "smime ... sign to message"
	
	$openssl_bin smime -sign -in $smime_enc -text -inform smime \
		-out $smime_sig -outform smime \
		-signer $user1_cert -inkey $user1_key -keyform pem \
		-passin pass:$user1_pass -md sha256 \
		-from user1@test_dummy.com -to server@test_dummy.com \
		-subject "test openssl smime"
	check_exit_status $?
	
	# pk7out
	start_message "smime ... pk7out from message"

	$openssl_bin smime -pk7out -in $smime_sig -out $smime_p7o
	check_exit_status $?

	# verify
	start_message "smime ... verify message"
	
	$openssl_bin smime -verify -in $smime_sig \
		-CAfile $ca_cert -certfile $user1_cert -nointern \
		-check_ss_sig -issuer_checks -policy_check -x509_strict \
		-signer $smime_sgr -text -out $smime_ver
	check_exit_status $?

	# decrypt
	start_message "smime ... decrypt message"

	$openssl_bin smime -decrypt -in $smime_ver -out $smime_dec \
		-recip $server_cert -inkey $server_key -passin pass:$server_pass
	check_exit_status $?

	diff $smime_dec $smime_txt
	check_exit_status $?
}

function test_ocsp {
	# --- OCSP operations ---
	section_message "OCSP operations"
	
	# get key without pass
	user1_key_nopass=$user1_dir/user1_key_nopass.pem
	$openssl_bin pkey -in $user1_key -passin pass:$user1_pass \
		-out $user1_key_nopass
	check_exit_status $?

	# request
	start_message "ocsp ... create OCSP request"
	
	ocsp_req=$user1_dir/ocsp_req.der
	$openssl_bin ocsp -issuer $ca_cert -cert $server_cert \
		-cert $revoke_cert -serial 1 -nonce -no_certs -CAfile $ca_cert \
		-signer $user1_cert -signkey $user1_key_nopass \
		-sign_other $user1_cert -sha256 \
		-reqout $ocsp_req -req_text -out $ocsp_req.out
	check_exit_status $?
	
	# response
	start_message "ocsp ... create OCPS response for a request"
	
	ocsp_res=$user1_dir/ocsp_res.der
	$openssl_bin ocsp -index  $ca_dir/index.txt -CA $ca_cert \
		-CAfile $ca_cert -rsigner $ocsp_cert -rkey $ocsp_key \
		-reqin $ocsp_req -rother $ocsp_cert -resp_no_certs -noverify \
		-nmin 60 -validity_period 300 -status_age 300 \
		-respout $ocsp_res -resp_text -out $ocsp_res.out
	check_exit_status $?
	
	# ocsp server
	start_message "ocsp ... start OCSP server in background"
	
	ocsp_port=8888
	
	ocsp_svr_log=$user1_dir/ocsp_svr.log
	$openssl_bin ocsp -index  $ca_dir/index.txt -CA $ca_cert \
		-CAfile $ca_cert -rsigner $ocsp_cert -rkey $ocsp_key \
		-host localhost -port $ocsp_port -path / -ndays 1 -nrequest 1 \
		-resp_key_id -text -out $ocsp_svr_log &
	check_exit_status $?
	ocsp_svr_pid=$!
	echo "ocsp server pid = [ $ocsp_svr_pid ]"
	sleep 1
	
	# send query to ocsp server
	start_message "ocsp ... send OCSP request to server"
	
	ocsp_qry=$user1_dir/ocsp_qry.der
	$openssl_bin ocsp -issuer $ca_cert -cert $server_cert \
		-cert $revoke_cert -CAfile $ca_cert -no_nonce \
		-url http://localhost:$ocsp_port -timeout 10 -text \
		-header Host localhost \
		-respout $ocsp_qry -out $ocsp_qry.out
	check_exit_status $?

	# verify response from server
	start_message "ocsp ... verify OCSP response from server"

	$openssl_bin ocsp -respin $ocsp_qry -CAfile $ca_cert \
	-ignore_err -no_signature_verify -no_cert_verify -no_chain \
	-no_cert_checks -no_explicit -trust_other -no_intern \
	-verify_other $ocsp_cert -VAfile $ocsp_cert
	check_exit_status $?
}

function test_pkcs {
	# --- PKCS operations ---
	section_message "PKCS operations"
	
	pkcs_pass=test-pkcs-pass
	
	start_message "pkcs7 ... output certs in crl(pkcs7)"
	$openssl_bin pkcs7 -in $crl_p7 -print_certs -text -out $crl_p7.out
	check_exit_status $?
	
	start_message "pkcs8 ... convert key to pkcs8"
	$openssl_bin pkcs8 -in $user1_key -topk8 -out $user1_key.p8 \
		-passin pass:$user1_pass -passout pass:$user1_pass \
		-v1 pbeWithSHA1AndDES-CBC -v2 des3
	check_exit_status $?
	
	start_message "pkcs8 ... convert pkcs8 to key in DER format"
	$openssl_bin pkcs8 -in $user1_key.p8 -passin pass:$user1_pass \
		-outform DER -out $user1_key.p8.der
	check_exit_status $?
	
	start_message "pkcs12 ... create"
	$openssl_bin pkcs12 -export -in $server_cert -inkey $server_key \
		-passin pass:$server_pass -certfile $ca_cert -CAfile $ca_cert \
		-caname "caname_server_p12" \
		-certpbe AES-256-CBC -keypbe AES-256-CBC -chain \
		-name "name_server_p12" -des3 -maciter -macalg sha256 \
		-CSP "csp_server_p12" -LMK -keyex \
		-passout pass:$pkcs_pass -out $server_cert.p12
	check_exit_status $?
	
	start_message "pkcs12 ... verify"
	$openssl_bin pkcs12 -in $server_cert.p12 -passin pass:$pkcs_pass -info \
		-noout
	check_exit_status $?
	
	start_message "pkcs12 ... private key to PEM without encryption"
	$openssl_bin pkcs12 -in $server_cert.p12 -password pass:$pkcs_pass \
		-nocerts -nomacver -nodes -out $server_cert.p12.pem
	check_exit_status $?
}

function test_server_client {
	# --- client/server operations (TLS) ---
	section_message "client/server operations (TLS)"

	s_id="$1"
	c_id="$2"
	sc="$1$2"

	test_pause_sec=0.2

	if [ $s_id = "0" ] ; then
		s_bin=$openssl_bin
	else
		s_bin=$other_openssl_bin
	fi

	if [ $c_id = "0" ] ; then
		c_bin=$openssl_bin
	else
		c_bin=$other_openssl_bin
	fi

	echo "s_server is [`$s_bin version`]"
	echo "s_client is [`$c_bin version`]"

	host="localhost"
	port=4433
	sess_dat=$user1_dir/s_client_${sc}_sess.dat
	s_server_out=$server_dir/s_server_${sc}_tls.out

	$s_bin version | grep 'OpenSSL 1.1.1' > /dev/null
	if [ $? -eq 0 ] ; then
		extra_opts="-4"
	else
		extra_opts=""
	fi
	
	start_message "s_server ... start TLS/SSL test server"
	$s_bin s_server -accept $port -CAfile $ca_cert \
		-cert $server_cert -key $server_key -pass pass:$server_pass \
		-context "appstest.sh" -id_prefix "APPSTEST.SH" -crl_check \
		-alpn "http/1.1,spdy/3" -www -cipher ALL $extra_opts \
		-msg -tlsextdebug > $s_server_out 2>&1 &
	check_exit_status $?
	s_server_pid=$!
	echo "s_server pid = [ $s_server_pid ]"
	sleep 1
	
	# protocol = TLSv1
	
	s_client_out=$user1_dir/s_client_${sc}_tls_1_0.out
	
	start_message "s_client ... connect to TLS/SSL test server by TLSv1"
	sleep $test_pause_sec
	$c_bin s_client -connect $host:$port -CAfile $ca_cert \
		-tls1 -msg -tlsextdebug < /dev/null > $s_client_out 2>&1
	check_exit_status $?
	
	grep 'Protocol  : TLSv1$' $s_client_out > /dev/null
	check_exit_status $?
	
	grep 'Verify return code: 0 (ok)' $s_client_out > /dev/null
	check_exit_status $?
	
	# protocol = TLSv1.1
	
	s_client_out=$user1_dir/s_client_${sc}_tls_1_1.out
	
	start_message "s_client ... connect to TLS/SSL test server by TLSv1.1"
	sleep $test_pause_sec
	$c_bin s_client -connect $host:$port -CAfile $ca_cert \
		-tls1_1 -msg -tlsextdebug < /dev/null > $s_client_out 2>&1
	check_exit_status $?
	
	grep 'Protocol  : TLSv1\.1$' $s_client_out > /dev/null
	check_exit_status $?
	
	grep 'Verify return code: 0 (ok)' $s_client_out > /dev/null
	check_exit_status $?
	
	# protocol = TLSv1.2
	
	s_client_out=$user1_dir/s_client_${sc}_tls_1_2.out
	
	start_message "s_client ... connect to TLS/SSL test server by TLSv1.2"
	sleep $test_pause_sec
	$c_bin s_client -connect $host:$port -CAfile $ca_cert \
		-tls1_2 -msg -tlsextdebug < /dev/null > $s_client_out 2>&1
	check_exit_status $?
	
	grep 'Protocol  : TLSv1\.2$' $s_client_out > /dev/null
	check_exit_status $?
	
	grep 'Verify return code: 0 (ok)' $s_client_out > /dev/null
	check_exit_status $?
	
	# all available ciphers with random order
	
	s_ciph=$server_dir/s_ciph_${sc}
	if [ $s_id = "0" ] ; then
		$s_bin ciphers -v ALL:!ECDSA:!kGOST | awk '{print $1}' > $s_ciph
	else
		$s_bin ciphers -v | awk '{print $1}' > $s_ciph
	fi

	c_ciph=$user1_dir/c_ciph_${sc}
	if [ $c_id = "0" ] ; then
		$c_bin ciphers -v ALL:!ECDSA:!kGOST | awk '{print $1}' > $c_ciph
	else
		$c_bin ciphers -v | awk '{print $1}' > $c_ciph
	fi

	ciphers=$user1_dir/ciphers_${sc}
	grep -x -f $s_ciph $c_ciph | sort -R > $ciphers

	cnum=0
	for c in `cat $ciphers` ; do
		cnum=`expr $cnum + 1`
		cnstr=`printf %03d $cnum`
		s_client_out=$user1_dir/s_client_${sc}_tls_${cnstr}_${c}.out
	
		start_message "s_client ... connect to TLS/SSL test server with [ $cnstr ] $c"
		sleep $test_pause_sec
		$c_bin s_client -connect $host:$port -CAfile $ca_cert \
			-cipher $c \
			-msg -tlsextdebug < /dev/null > $s_client_out 2>&1
		check_exit_status $?
	
		grep "Cipher    : $c" $s_client_out > /dev/null
		check_exit_status $?
	
		grep 'Verify return code: 0 (ok)' $s_client_out > /dev/null
		check_exit_status $?
	done
	
	# Get session ticket to reuse
	
	s_client_out=$user1_dir/s_client_${sc}_tls_reuse_1.out
	
	start_message "s_client ... connect to TLS/SSL test server to get session id"
	sleep $test_pause_sec
	$c_bin s_client -connect $host:$port -CAfile $ca_cert \
		-alpn "spdy/3,http/1.1" -sess_out $sess_dat \
		-msg -tlsextdebug < /dev/null > $s_client_out 2>&1
	check_exit_status $?
	
	grep '^New, TLS.*$' $s_client_out > /dev/null
	check_exit_status $?
	
	grep 'Verify return code: 0 (ok)' $s_client_out > /dev/null
	check_exit_status $?
	
	# Reuse session ticket
	
	s_client_out=$user1_dir/s_client_${sc}_tls_reuse_2.out
	
	start_message "s_client ... connect to TLS/SSL test server reusing session id"
	sleep $test_pause_sec
	$c_bin s_client -connect $host:$port -CAfile $ca_cert \
		-sess_in $sess_dat \
		-msg -tlsextdebug < /dev/null > $s_client_out 2>&1
	check_exit_status $?
	
	grep '^Reused, TLS.*$' $s_client_out > /dev/null
	check_exit_status $?
	
	grep 'Verify return code: 0 (ok)' $s_client_out > /dev/null
	check_exit_status $?
	
	# invalid verification pattern
	
	s_client_out=$user1_dir/s_client_${sc}_tls_invalid.out
	
	start_message "s_client ... connect to TLS/SSL test server but verify error"
	sleep $test_pause_sec
	$c_bin s_client -connect $host:$port -CAfile $ca_cert \
		-showcerts -crl_check -issuer_checks -policy_check \
		-msg -tlsextdebug < /dev/null > $s_client_out 2>&1
	check_exit_status $?
	
	grep 'Verify return code: 0 (ok)' $s_client_out > /dev/null
	if [ $? -eq 0 ] ; then
		check_exit_status 1
	else
		check_exit_status 0
	fi
	
	# s_time
	start_message "s_time ... connect to TLS/SSL test server"
	$c_bin s_time -connect $host:$port -CApath $ca_dir -time 2
	check_exit_status $?
	
	# sess_id
	start_message "sess_id"
	$c_bin sess_id -in $sess_dat -text -out $sess_dat.out
	check_exit_status $?
	
	stop_s_server
}

function test_speed {
	# === PERFORMANCE ===
	section_message "PERFORMANCE"
	
	if [ $no_long_tests = 0 ] ; then
		start_message "speed"
		$openssl_bin speed sha512 rsa2048 -multi 2 -elapsed
		check_exit_status $?
	else
		start_message "SKIPPING speed (quick mode)"
	fi
}

function test_version {
	# --- VERSION INFORMATION ---
	section_message "VERSION INFORMATION"
	
	start_message "version"
	$openssl_bin version -a
	check_exit_status $?
}

#---------#---------#---------#---------#---------#---------#---------#---------

openssl_bin=${OPENSSL:-/usr/bin/openssl}
other_openssl_bin=${OTHER_OPENSSL:-/usr/local/bin/eopenssl}

interop_tests=0
no_long_tests=0

while [ "$1" != "" ]; do
	case $1 in
		-i | --interop)		shift
					interop_tests=1
					;;
		-q | --quick )		shift
					no_long_tests=1
					;;
		* )			usage
					exit 1
	esac
done

if [ ! -x $openssl_bin ] ; then
	echo ":-< \$OPENSSL [$openssl_bin]  is not executable."
	exit 1
fi

if [ $interop_tests = 1 -a ! -x $other_openssl_bin ] ; then
	echo ":-< \$OTHER_OPENSSL [$other_openssl_bin] is not executable."
	exit 1
fi

#
# create ssldir, and all files generated by this script goes under this dir.
#
ssldir="appstest_dir"

if [ -d $ssldir ] ; then
	echo "directory [ $ssldir ] exists, this script deletes this directory ..."
	/bin/rm -rf $ssldir
fi

mkdir -p $ssldir

ca_dir=$ssldir/testCA
tsa_dir=$ssldir/testTSA
ocsp_dir=$ssldir/testOCSP
server_dir=$ssldir/server
user1_dir=$ssldir/user1
mkdir -p $user1_dir
key_dir=$ssldir/key
mkdir -p $key_dir

export OPENSSL_CONF=$ssldir/openssl.cnf
touch $OPENSSL_CONF

uname_s=`uname -s | grep 'MINGW'`
if [ "$uname_s" = "" ] ; then
	mingw=0
else
	mingw=1
fi

#
# process tests
#
test_usage_lists_others
test_md
test_encoding_cipher
test_key
test_pki
test_tsa
test_smime
test_ocsp
test_pkcs
test_server_client 0 0
if [ $interop_tests = 1 ] ; then
	test_server_client 0 1
	test_server_client 1 0
fi
test_speed
test_version

section_message "END"

exit 0

