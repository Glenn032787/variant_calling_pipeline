#!/bin/bash
#PBS -N PrimaryPipeline
#PBS -V
#PBS -o /mnt/causes-vnx2/glenn/fq/script.o
#PBS -e /mnt/causes-vnx2/glenn/fq/script.e
#PBS -m bea
#PBS -l walltime=200:00:00
#PBS -l nodes=1:ppn=8

# Main script which loops through file (SampleIDs) and run variant calling for each using the v38 and T2T reference genome.
# Resulting variant calling file will be in /v38 and /T2T directory. 
# log_file will be created to keep track on file being worked on 

curr_dir='/mnt/causes-vnx2/glenn'
name_file=${curr_dir}'/fq/sampleIDs'
log_file=${curr_dir}'/fq/log_file'
pipeline_file=${curr_dir}'/fq/pipeline.sh'

echo ${curr_fir} > ${log_file}

cat ${name_file} | while read line
do
	INPUT_NAME=$(echo ${line} | cut -d' ' -f1)
	OUTPUT_NAME=$(echo ${line}| cut -d' ' -f2)
	
	echo $INPUT_NAME >> ${log_file}

	ls ${curr_dir}/fq/${INPUT_NAME}*R1* &> /dev/null
	ec1=$?
	ls ${curr_dir}/fq/${INPUT_NAME}*R2* &> /dev/null
	ec2=$?	

	if [[ $ec1 == 0 &&  $ec2 == 0 ]]; then 
		# Run script with v38	
		if ! ls ${curr_dir}/v38/${OUTPUT_NAME}* &> /dev/null; then
			echo "Starting ${INTPUT_NAME} with v38" >> ${log_file}
			${pipeline_file} ${INPUT_NAME} ${OUTPUT_NAME} v38
			echo "Finish ${INPUT_NAME} with v38" >> ${log_file}
		else
			echo "${INPUT_NAME} with v38 is already done" >> ${log_file}
		fi
		
		# Run script with T2T	
		if ! ls ${curr_dir}/T2T/${OUTPUT_NAME}* &> /dev/null; then
			echo "Starting ${INTPUT_NAME} with T2T" >> ${log_file}
			${pipeline_file} ${INPUT_NAME} ${OUTPUT_NAME} T2T
			echo "Finish ${INTPUT_NAME} with T2T" >> ${log_file}
		else
			echo "${INPUT_NAME} with T2T is already done" >> ${log_file}
		fi
	else
		echo "${INPUT_NAME} files not found" >> ${log_file}
	fi
	echo "" >> ${log_file}
done 	
