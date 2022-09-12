#! /bin/bash

# Default values
stage=0
unique_stage=true
P2PaLA_PATH="./tools/P2PaLA"
htrsh_PATH="./tools/htrsh"
CurvatureCorrectionExtractor_PATH="./tools/CurvatureCorrectionExtractor"

if [ $# -eq 0 ]; then
  echo "########################################"
  echo "Use: bash ${0##*/} [options]"
  echo "Options:"
  echo " -s Stage: [0: Data preparation,"
  echo "            1: Train P2PaLA model,"
  echo "            2: Improve contours,"
  echo "            3: Extract features,"
  echo "            4: Evaluate with CI]"
  echo " -u Unique stage: $unique_stage"
  echo " -p Path to P2PaLA: $P2PaLA_PATH"
  echo " -h Path to htrsh: $htrsh_PATH"
  echo " -c Path to CurvatureCorrectionExtractor: $CurvatureCorrectionExtractor_PATH"
  echo "########################################"
  exit 0
fi

while getopts s:u:p:h:c: flag
do
  case "${flag}" in
    s) stage=${OPTARG};;
    u) unique_stage=${OPTARG};;
    p) P2PaLA_PATH=${OPTARG};;
    h) htrsh_PATH=${OPTARG};;
    c) CurvatureCorrectionExtractor_PATH=${OPTARG};;
  esac
done

source "${htrsh_PATH}/htrsh.inc.sh"


if [ "$stage" -le 0 ]; then
  echo "########################################"
  echo "# Prepare the data"
  echo "########################################"
  [ ! -d data ] && mkdir -p data/{0,1}/{train,val,test}/page
  [ ! -d GT ] && ln -s ../GT ./
  find  ./GT/ -name "*0.jpg" > /tmp/files_0.lst
  find  ./GT/ -name "*1.jpg" > /tmp/files_1.lst

  for page in "0" "1"; do
    for part in "train" "val" "test"; do
      while read f; do
        f=$(grep $f /tmp/files_${page}.lst)
        ln -s ../../../$f data/${page}/${part}/;
        # Remove TableCell regions in xml
	gawk '{if($0~"<TableCell"){ getline; }else{ if($0~"CornerPts") getline; else{ if($0~"</TableCell") getline; else print $0}}}' $(dirname $f)/page/$(basename $f .jpg).xml | sed 's/TableRegion/TextRegion/g' | sed 's/TableCell/TextRegion/g' > data/${page}/${part}/page/$(basename $f .jpg).xml

      done < GT/PARTITIONS/${part}.lst
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 1 ]; then
  echo "########################################"
  echo "# Train the P2PaLA models for test"
  echo "########################################"
  [ ! -d conf ] && mkdir conf
  [ ! -d logs ] && mkdir logs

  for page in "0" "1"; do
    # Configuration file for P2PaLA
    cat << EOF> conf/P2PaLA_${page}.conf
--exp_name HisClima_${page}
--gpu 0
--seed 42
--work_dir work_${page}
--log_level DEBUG
--num_workers 4
--img_size 1024 768
--line_color 128
--line_width 4
--approx_alg optimal
--num_segments 2
--batch_size 4
--input_channels 3
--out_mode L
--net_out_type C
--cnn_ngf 64
--loss_lambda 100
--g_loss L1
--adam_lr 0.001
--adam_beta1 0.5
--adam_beta2 0.999
--epochs 300
--max_vertex 30
--e_stdv 6
--min_area 0.01
--do_train
--tr_data ./data/${page}/train/
--do_val
--val_data ./data/${page}/val/
--do_test
--te_data ./data/${page}/test/
--no-do_prod
--max_vertex 30
EOF
    python3.7 "${P2PaLA_PATH}/P2PaLA.py" \
      --config conf/P2PaLA_${page}.conf \
      --log_comment "Hisclima-${page}" 2>> logs/HisClima_${page}.log

    # Get F1 for test pages
    find data/${page}/test/page -name "*xml" > ./ref
    find work_${page}/results/test/page -name "*xml" > ./hyp
    python3.7 "${P2PaLA_PATH}/evalTools/page2page_eval.py" \
      --target_list ./ref \
      --hyp_list ./hyp 2>> logs/HisClima_${page}.log
    done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi

if [ "$stage" -le 2 ]; then
  echo "########################################"
  echo "# Improve the contours"
  echo "########################################"
  [ -d results ] || mkdir -p results/{0,1}/test/page

  for page in "0" "1"; do
    for n in $(ls work_${page}/results/test/page); do
      echo $n
      pageGenerateContour -a 45 -d 10 -i work_${page}/results/test/page/"${n}" -o /tmp/${n}
      cat /tmp/${n} | htrsh_pagexml_sort_lines | htrsh_pagexml_relabel | awk '{if(($0!~"TextEquiv>")&&($0!~"Unicode*")) print $0}' > results/${page}/test/page/"${n}"
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 3 ]; then
  echo "########################################"
  echo "# Extracting the CurvatureCorrectionExtractor features"
  echo "########################################"
  TMPD=/tmp
  np=3
  for page_side in "0" "1"; do
    work="./results/${page_side}/test/feats/"
    log_file="./logs/HisClima_feats_extraction_${page_side}.log"

    echo "CurvatureCorrectionExtractor extraction: $(date)" | tee -a "${log_file}"

    for page in $(find ./results/${page_side}/test/page/ -name "*.xml" | grep "\/page\/"); do
      [ -d ${work}/$(basename "$page" .xml) ] && rm -r ${work}/$(basename "$page" .xml)
      mkdir -p ${work}/$(basename "$page" .xml)
      (
        python3 "${CurvatureCorrectionExtractor_PATH}/curvatureCorrectionExtractor.py" "$page" data/${page_side}/test/$(basename "$page" .xml).jpg ${work}/$(basename "$page" .xml) 1 0.2 0 0 0.4 0.05 0 0 BLANK
        n_xml=$(grep '<TextLine' ${page} | wc -l)
        n_feats=$(find ${work}/$(basename "$page" .xml) -name "*png"| wc -l)
        n_lines=$n_feats # We are not extracting the raw lines
        echo $(date)": File ID: $(basename $page .xml), \
        extracted lines: $n_lines, \
        extracted features: $n_feats \
        $([ "$n_xml" == "$n_feats" ] && \
        echo $([ $n_feats == $n_lines ] && echo " ; Correct" || \
        echo " ; ERROR in feature extraction") || echo " ; ERROR in line extraction")"
      ) &>> "${log_file}" &
      bkg_pids+=("$!");
      ## Wait for jobs to finish when number of running jobs = number of processors
      if [ "${#bkg_pids[@]}" -eq "$np" ]; then
        for n in $(seq 1 "${#bkg_pids[@]}"); do
            wait "${bkg_pids[n-1]}" || (
            echo "Failed image processing:" >&2 && cat "$TMPD/$((n-1))" >&2 && exit 1;
            );
        done;
        bkg_pids=();
      fi;
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 4 ]; then
  echo "########################################"
  echo "# Evaluate Layout Analysis with confience intervals"
  echo "########################################"
  
  for page_side in "0" "1"; do
    for partition in "val" "test"; do
      grep "xml" logs/HisClima_${page_side}.log | grep "$partition" | grep -v "DEBUG" | sed 's/, d.*\// /' | sed 's/\.xml//' | sed 's/,//g' | awk 'BEGIN{print "P R F_1"}{print $1" "$2" "$3}' | tee /tmp/data

      Rscript boostrap_ci.R /tmp/data | tee logs/HisClima_${page_side}_${partition}_stats.log
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi
