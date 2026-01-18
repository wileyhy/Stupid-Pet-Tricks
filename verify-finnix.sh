#! /bin/sh
# verify-finnix.sh
# 
# Relevant websites, c. Jan 2026
# 	https://www.finnix.org
#	https://github.com/finnix/finnix-docs
#	https://ftp-osl.osuosl.org/pub/finnix/current
#
# List of required files
# 	finnix-251.iso	-- Available at mirrors
#	finnix-251.gpg  -- Available at mirrors
#	251.json        -- Available at finnix-docs/releases


# Variables
hash_ff=checksums.txt
ssh_key='AAAAC3NzaC1lZDI1NTE5AAAAIJQEw5EJeL+lHS9Dq8iU8vgVgU6VAb+sVsitQU8tHl38'
ssh_eml='file-signing@finnix.org'

# Debugging
#set -x
set -e
set -u
set -C


# Functions
_fn_err_ex_ ()
{
	printf 'Error: line %d;\t' "$1"
	shift
	printf '%s\n'
	exit 1
}


# List of required commands
if command -v awk gpg grep jq md5sum sha256sum sha512sum ssh-keygen >/dev/null
then : t
else : -t
	_fn_err_ex_ "${LINENO}" "Command not found"
fi


# Identify the files in the CWD
out_find=$( find ./* -prune -type f )
if [ -n "${out_find}" ]
then : t
	# identify ISO file
	iso_relpth=$( printf '%s' "${out_find}" \
		| grep -xEe '.*\.iso'$
	)
	iso_abspth=$( realpath -e -- "${iso_relpth}" )
	if [ -n "${iso_abspth}" ]
	then : t
	else : -t
		_fn_err_ex_ "${LINENO}" "File not found"
	fi
		#exit 101

	# identify PGP file
	gpg_relpth=$( printf '%s' "${out_find}" \
		| grep -xEe '.*\.iso\.gpg'$
	)
	gpg_abspth=$( realpath -e -- "${gpg_relpth}" )
	if [ -n "${gpg_abspth}" ]
	then : t
	else : -t
		_fn_err_ex_ "${LINENO}" "File not found"
	fi

	# identify OS major version of ISO file
	maj_vers=$( printf '%s' "${gpg_relpth}" \
		| sed   -e 's,^\(\./\)\?finnix-,,' \
			-e 's,.iso.*$,,' \
		| sort -u 
	)
	if [ -n "${maj_vers}" ]
	then : t
		if printf '%s' "${maj_vers}" | grep -qxEe '[0-9]{3,}+'
		then : t
		else : -t
			_fn_err_ex_ "${LINENO}" "Data not found"
		fi
	else : -t
		_fn_err_ex_ "${LINENO}" "Data not found"
	fi

	# identify JSON file
	jsn_relpth=$( printf '%s' "${out_find}" \
		| grep -xEe '(./)?'"${maj_vers}"'\.json' \
	)
	jsn_abspth=$( realpath -e -- "${jsn_relpth}" )
	if [ -n "${jsn_abspth}" ]
	then : t
	else : -t
		_fn_err_ex_ "${LINENO}" "File not found"
	fi

	# identify current PGP cryptographic key from output of \gpg --verify\
	out_0_gpg=$( gpg --verify -- "${gpg_abspth}" "${iso_abspth}" 2>&1 )
	out_1_gpg=$( printf '%s' "${out_0_gpg}" \
		| grep -e ^"gpg: Signature made "
	)
	# some output must exist
	if [ -n "${out_0_gpg}" ]
	then : t
		# a \signature\ must exist
		if [ -n "${out_1_gpg}" ]
		then : t
			out_2_gpg=$( printf '%s' "${out_0_gpg}" \
				| grep -e ' using RSA key ' \
				| grep -iEe '[0-9a-f]{40}'
			)
			# an RSA key must exist
			if [ -n "${out_2_gpg}" ]
			then : t
				# print the full 40 character PGP key identifier
				out_3_gpg=$( printf '%s' "${out_2_gpg}" \
					| awk '{ split($0,arr); for (xx in arr) { 
						if (arr[xx] ~ /[0-9a-fA-F]{40}/) {
							print arr[xx]
							}
						}
					}'
				)
			else : -t
			fi
		else : -t
			_fn_err_ex_ "${LINENO}" "Data not found"
		fi
	else : -t
		_fn_err_ex_ "${LINENO}" "Data not found"
	fi
else : -t
	_fn_err_ex_ "${LINENO}" "Files not found"
fi
	# Review data
	#set -x
	:;:;: 
	: "out_find:    ${out_find}"
	: "iso_relpth:  ${iso_relpth}"
	: "iso_abspth:  ${iso_abspth}"
	: "gpg_abspth:  ${gpg_abspth}"
	: "jsn_abspth:  ${jsn_abspth}"
	: "maj_vers:    ${maj_vers}"
	: "out_0_gpg:   ${out_0_gpg}"
	: "out_1_gpg:   ${out_1_gpg}"
	: "out_2_gpg:   ${out_2_gpg}"
	: "out_3_gpg:   ${out_3_gpg}"
	#exit 101
	#set -x


# Obtain a copy of the PGP public signing key from online
if [ -n "${out_3_gpg}" ] 
then : t
	rcv_0_out=$( gpg --receive-keys -- "${out_3_gpg}" 2>&1 )
	if [ -n "${rcv_0_out}" ]
	then : t
		# receive least one PGP key
		rcv_1_out=$( printf '%s' "${rcv_0_out}" \
			| awk '/^gpg: Total number processed: / {
				print $NF
			}'
		)
		if [ -n "${rcv_1_out}" ]
		then : t
			if [ "${rcv_1_out}" -ne 0 ]
			then : t
				printf 'PGP key received\n'
			else : -t
				_fn_err_ex_ "${LINENO}" "Data not found"
			fi
		else : -t
			_fn_err_ex_ "${LINENO}" "Data not found"
		fi
	else : -t
	fi

	# Verify the ISO file using PGP
	veri_0_out=$( gpg --verify -- "${gpg_abspth}" "${iso_abspth}" 2>&1 )
	if [ -n "${veri_0_out}" ]
	then : t
		veri_1_out=$( printf '%s' "${veri_0_out}" \
       			| awk '/^gpg: Good signature from/ {
				if (/[Ff]innix/) {
					print "Good"
				} else {
					print "Not so good"
				}
			}'
		)
		if [ "${veri_1_out}" = Good ]
		then : t
			printf 'Good signature from Finnix\n'

			# Optional
			veri_2_out=$( printf '%s' "${veri_0_out}" \
	       			| grep 'Primary key fingerprint: ' \
				| sed 's,^Primary key fingerprint: ,,'
			)
			printf 'PGP Fingerprint: %s\n' "${veri_2_out}"
		else : -t
			_fn_err_ex_ "${LINENO}" "Data not found"
		fi
	else : -t
	fi
else : -t
fi
	#set -x
	:;:;:
	: "rcv_0_out: ${rcv_0_out}"
	: "rcv_1_out: ${rcv_1_out}"
	: "veri_0_out: ${veri_0_out}"
	: "veri_1_out: ${veri_1_out}"
	: "veri_2_out: ${veri_2_out}"
	#exit 101
	#set -x


# verify the checksums listed in the the JSON file
for HH in md5 sha256 sha512
do
	unset value
	jq '.finnix .releases ."'"${maj_vers}"'" .architectures .amd64
		.files ."finnix-251.iso" .checksums .'"${HH}" \
		./"${maj_vers}.json" \
		| tee "${hash_ff}" >/dev/null
	sleep .1

	value=$( command "${HH}sum" -- "${iso_abspth}" \
		| awk '{ print $1 }' 
	)
	if grep -qe "${value}" "${hash_ff}"
	then : t
		printf '%s hash sum verified\n' "${HH}"
	else : -t
		_fn_err_ex_ "${LINENO}" "Data not found"
	fi
done
unset HH
	:;:;:
	: ": value: ${value}"
	#exit 101
	#set -x


# Verify the cryptographic signatures listed in the JSON file
#
# GPG data
local_pgp_ff=finnix-251.iso.gpg2
pgp_sig=$( jq '.finnix .releases ."'"${maj_vers}"'" .architectures .amd64 .files ."finnix-'"${maj_vers}"'.iso" .signatures[] | select(.type == "openpgp") | .signature' "${jsn_abspth}"
)
pgp_sig=${pgp_sig#'"'}
pgp_sig=${pgp_sig%'"'}
if [ -n "${pgp_sig}" ]
then : t
	# write secondary gpg signature to disk
	printf '%b\n' "${pgp_sig}" \
		| tee "${local_pgp_ff}" >/dev/null
	
	# verify the two GPG files are identical
	if diff "${gpg_abspth}" "${local_pgp_ff}"
	then : t
		printf 'Secondary GPG data: verified\n'
	else : -t
		_fn_err_ex_ "${LINENO}" "Data does not match"
	fi
else : -t
	_fn_err_ex_ "${LINENO}" "Data not found"
fi



local_ssh_ff=finnix-251.iso.sig
ssh_sig=$( jq '.finnix .releases ."251" .architectures .amd64 .files 
	."finnix-251.iso" .signatures[] 
	| select(.type == "ssh") 
	| .signature' "${jsn_abspth}"
)
ssh_sig=${ssh_sig#'"'}
ssh_sig=${ssh_sig%'"'}
if [ -n "${ssh_sig}" ]
then : t
	printf '%b' "${ssh_sig}" \
		| tee "${local_ssh_ff}" >/dev/null

	# Data from Github wiki page
	printf '%s %s %s %s\n' "${ssh_eml}" 'ssh-ed25519' "${ssh_key}" \
		'Finnix file-signing' \
		| tee ./authorized_signers >/dev/null

	ssh-keygen -Y verify -f ./authorized_signers -I "${ssh_eml}" \
		-n file -s ./"finnix-${maj_vers}.iso.sig" \
		< ./"finnix-${maj_vers}.iso"

else : -t
	_fn_err_ex_ "${LINENO}" "Data not found"
fi
exit 00

