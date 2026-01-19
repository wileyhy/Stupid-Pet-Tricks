#!/bin/bash
# benchmark-hashing-programs.sh
# Wiley Young 2025 GPLv3
#
# Compare hash speeds at nane-seconds per byte, averaged over
# some thousands of iterations.


programs=(     # DIGEST-LENGTH
  sum          #     5 c
  cksum        #     9 c
  md5sum       #     32 c
  sha1sum      #     40 c
  sha224sum    #     56 c
  sha256sum    #     64 c
  sha384sum    #     96 c
  b2sum        #     128 c
  sha512sum    #     128 c
)

  #:;:;: # Debugging
  #declare -p programs
  #exit 99
  #reset
  #set -x


# Test file
zero_ff=/tmp/block-file.zero
file_sz=$(( 2 ** 12 ))
if [ -f "${zero_ff}" ]
then : t
  rm -f "${zero_ff}"
else : -t
fi
dd if=/dev/zero of="${zero_ff}" bs="${file_sz}" count=1 2> /dev/null


# Iterations
iterations=10000
export iterations


# Initial output
printf '# Hashing %d bytes for %d iterations\n' "${file_sz}" "${iterations}"

  #set -x


# Test each hash binary
for HH in "${programs[@]}"
do
  # Gather inf
  out_cmd=$( command -v "${HH}" )
  out_rlpth=$( realpath -e "${out_cmd}" )
  orig_rpm=$( rpm -qf "${out_rlpth}" )

  # Data must exist, and must be an executable file
  if [ -n "${out_rlpth}" ] \
    && [ -x "${out_rlpth}" ]
  then
    export HH=${out_rlpth}
    
    # Print a section header
    printf '#\t%s  --  %s\n' "${out_rlpth}" "${orig_rpm}" 
  else
    printf '#\t\tExecutable file not found: %s\n' "${out_rlpth}"
    continue
  fi

  # Turn off xtrace
  [ "${-//[a-wyzA-WYZ]}" = x ] && set -

  # (re)set index variable
  ii=0
  export ii
  {
    set -o posix
    TT=$(
      { time -p sh -c '
          while [ "${ii}" -le "${iterations}" ]
          do
            command "${HH}" "${zero_ff}" >/dev/null 2>&1
            ii=$(( ${ii} + 1 ))
          done 2>&1 \
            | tail -n 3'
      } 2>&1
    )
    set +o posix
  }

    #:;:;: # Debugging
    #echo "TT: $TT"
    #exit 101
    #set -x

  real=$( printf '%s' "${TT}" | awk '/real/ { print $2 }' )
  user=$( printf '%s' "${TT}" | awk '/user/ { print $2 }' )
  sys=$(  printf '%s' "${TT}" | awk '/sys/  { print $2 }' )

    #:;:;: # Debugging
    #echo "real: ${real}"
    #echo "user: ${user}"
    #echo "sys: ${sys}"
    #exit 101

  # Use \bc\ for floating point arithmetic. Note, \bc\ requires a
  # trailing newline
  bc_scl=24
  elapsed_tt=${real}
  seconds=$( printf 'scale=%d; %s / %s\n' "${bc_scl}" "${elapsed_tt}" \
      "${iterations}" \
    | bc -s --
  )
  secs_per_byte=$( printf 'scale=%d; %s / %s\n' "${bc_scl}" "${seconds}" \
      "${file_sz}" \
    | bc -s --
  )
  nano_per_byte=$( printf 'scale=%d; %s * ( 10 ^ 9 )\n' "${bc_scl}" \
      "${secs_per_byte}" \
    | bc -s --
  )
  nano_per_byte=$( printf '%s' "${nano_per_byte}" | sed -e 's,0*$,,' )

    #:;:;: # Debugging
    #echo "elapsed_tt: ${elapsed_tt}"
    #echo "seconds: ${seconds}"
    #echo "secs_per_byte: ${secs_per_byte}"
    #echo "nano_per_byte: ${nano_per_byte}"
    #exit 101

  printf '#\t\t%s elapsed time\n' "${elapsed_tt}"
  #printf '#\t\t%s seconds\n' "${seconds}"
  #printf '#\t\t%s seconds per byte\n' "${secs_per_byte}"
  #printf '#\t\t-------^^^^---\n'
  printf '#\t\t%s nano-seconds per byte\n' "${nano_per_byte}"
done

rm -f "${zero_ff}"
exit 00

