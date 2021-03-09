#!/bin/bash
#set -x



# Update this list with your list of masternode's protx hash, leave a space between each one, they must all be on a single unbroken line.
MASTERNODES=(44630ddbd95f62c8667725d6da1c910ea7ae44cf58a59a639cbee9c76b554da0 73259e2f47351c662728078f5d77140ec8922e792d6c423dcc5b06f02f5fb2df d8771bd91a030ec0f09dbcb669f6772ed67576c0a3f797d0082aad81cf61857f 21191025c337bf3aae55f39d34ac1fa32444be8dbaa3bf4e5c1bc62b4cdaab1e c74633e3ea2e2ed1977f2657c3ed23c176b1cd5e6966d43984b0f6ac072e305e 972f35055a6bb93993c238836f0b994c089b26227cc5eff289bb930c12b45e5d 7166801342a2f09358ae4d3720f912c439605db9f58af362e9eccd44e8509fbb e8ce80ea903a5f4af70dfed189fbcf6926374743202c4cedafe58c21eafdc51b a569acf816ff49a72c18a62bdcc59bb95ed962c9c6ceae2fb4006e30d1946700 65650b10d273b74db238649477bc24222b4171cc1bbb8e0bd414d0eedee76f4f f134927ab6aeed105d1ac93ca3b9d2f197831abad91540e125aec03e8ae33437 7afd763df1b77ac1e9fa2a43d7387142fba5bb10e89462b16c9d1d14347d4c4c 1375ce3e596e7d5532c6e68816607a4b116bb7eb8a158354fc6003934c5a474a ec025e6e243227d40c7b0bce0873d14ed9e7a60d9318c7bdb1606284a066f7bf 5455f914293de40a2390c3cc6d607147b3a9516aad56f99c91fded420ff2ffbf 1ab2a188578b7344b638500f024c028582fb2ac698e2acd54c0cfba2d9e9ffbf 2833ec6e1f256e749bd53f56e444b28cf1d75a851b123fc32089bb58249e9fdf c769f117d2f154240e0a3b5e223a10e370d3567afc0494d4e697390ff9947c7f)

# Checks that the required software is installed on this machine.
bc -v >/dev/null 2>&1 || progs+=" bc"
jq -V >/dev/null 2>&1 || progs+=" jq"

if [[ -n $progs ]];then
	text="Missing applications on your system, please run\n\n"
	text+="\tsudo apt install $progs\n\nbefore running this program again."
	echo -e "$text" >&2
	exit 1
fi


CURRENT_BLOCK=$(dash-cli getblockcount)
if (( $? != 0 ));then
	echo "Problem running dash-cli, make sure it is in your path and working..."
	exit 1
fi

MN_FILTERED=$(dash-cli protx list|jq -r .[]|grep $(echo "${MASTERNODES[@]}"|sed 's/ /\\|/g'))
for (( i=0; i < ${#MASTERNODES[*]}; i++ ))
do
	if echo "$MN_FILTERED"|grep -q "${MASTERNODES[$i]}";then
		# Protx provided is in the protx list, so extract some facts about this masternode.
		protx_info=$(dash-cli protx info ${MASTERNODES[$i]})
		lastpaidheight=$(jq -r '.state.lastPaidHeight'<<<"$protx_info")
		service=$(jq -r '.state.service'<<<"$protx_info"|sed 's/:.*//g')
		if (( lastpaidheight == 0 ));then
			echo "$lastpaidheight:This masternode ${MASTERNODES[$i]} on $service has never been paid"
		else
			# Number of blocks since we got paid.
			blocks=$((CURRENT_BLOCK-lastpaidheight))
			minutes=$(bc<<<"$blocks * 2.625"|sed 's/\..*//g')
			if (( minutes < 120 ));then
				echo "$lastpaidheight:This masternode ${MASTERNODES[$i]} on $service was paid $minutes minutes ago."
			elif (( $minutes < 2880 ));then
				hours=$(bc<<<"$minutes / 60")
				echo "$lastpaidheight:This masternode ${MASTERNODES[$i]} on $service was paid $hours hours ago."
			else
				days=$(bc<<<"$minutes / 60 / 24")
				echo "$lastpaidheight:This masternode ${MASTERNODES[$i]} on $service was paid $days days ago."
			fi
		fi
	fi
done|sort -r|awk -F : '{print $2}'

