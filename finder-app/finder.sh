if [ $# -ne 2 ]
then 
	echo "Not enough args "
	exit 1
else
	if ! [ -d $1 ]
	then
		echo "Wrong directory" 
	fi
fi 

num_of_files=$(ls $1 | wc -l )
num_of_lines=$(grep -rnw $1 -e $2 | wc -l)

echo "The number of files are ${num_of_files} and the number of matching lines are ${num_of_lines}"
exit 0
