#! /bin/bash

# Default values
stage=0
unique_stage=true
TextExtractor_PATH="./tools/TextExtractor"
htrsh_PATH="./tools/htrsh"
CurvatureCorrectionExtractor_PATH="./tools/CurvatureCorrectionExtractor"

if [ $# -eq 0 ]; then
  echo "########################################"
  echo "Use: bash ${0##*/} [options]"
  echo "Options:"
  echo " -s Stage: [0: Textual data preparation,"
  echo "            1: Extract features,"
  echo "            2: Prepare partitions,"
  echo "            3: Obtain symbols,"
  echo "            4: Remove small images"
  echo "            5: Train optical models"
  echo "            6: CTC decode"
  echo "            7: Evaluate CTC"
  echo "            8: Get confidence matrix"
  echo "            9: LM preparation"
  echo "           10: Decoding with LM optimization"
  echo "           11: Lattices generation"
  echo "           12: Add best hypothesis to page files"
  echo "           13: Evaluate lattice generation"
  echo "           14: Evaluate lattice density"
  echo "           15: Get sample list for DLA test"
  echo "           16: CTC decode DLA test"
  echo "           17: Get confidence matrix DLA test"
  echo "           18: Lattices generation DLA test"
  echo "           19: Add best hypothesis to page files DLA test"
  echo "           20: Evaluate lattice density DLA test"
  echo "           21: Get textual corpus statistics]"
  echo " -u Unique stage: $unique_stage"
  echo " -t Path to TextExtractor: $TextExtractor_PATH"
  echo " -h Path to htrsh: $htrsh_PATH"
  echo " -c Path to CurvatureCorrectionExtractor: $CurvatureCorrectionExtractor_PATH"
  echo "########################################"
  exit 0
fi

while getopts s:u:t:h:c: flag
do
  case "${flag}" in
    s) stage=${OPTARG};;
    u) unique_stage=${OPTARG};;
    t) TextExtractor_PATH=${OPTARG};;
    h) htrsh_PATH=${OPTARG};;
    c) CurvatureCorrectionExtractor_PATH=${OPTARG};;
  esac
done

source "${htrsh_PATH}/htrsh.inc.sh"

# Prepare textual data
if [ "$stage" -le 0 ]; then
  echo "########################################"
  echo "# Prepare textual data"
  echo "########################################"

  [ -d data/text ] || mkdir -p data/text
  [ -d data/page ] || mkdir -p data/page{0,1}
  [ -d GT ] || ln -s ../GT ./

  for f in $(find ./GT -name "*.xml"); do
    page=$(basename "$f" .xml | tail -c 2)
    cp $f data/page/${page}/$(basename "$f")
    python3 "${TextExtractor_PATH}/textExtractor.py" "$f"
  done | tr -s ' ' | tee /tmp/log | sort -k1 > data/text/transcriptions.txt

  # Change to upcase without diacritics
  iconv -f utf8 data/text/transcriptions.txt | awk '{a=$1; $0=toupper($0); $1=a; print $0}' > data/text/transcriptions_word.txt

  sed -i 's/\(\!PRINT\)/\L\1/g' data/text/transcriptions_word.txt
  sed -i 's/\(\!BLANK\)/\L\1/g' data/text/transcriptions_word.txt
  sed -i 's/!MANUSCRIPT//g' data/text/transcriptions_word.txt

   # Change the decimal point to <decimal>
  sed -i 's/\([0-9]\)\.\([0-9]\)/\1<decimal>\2/' data/text/transcriptions_word.txt

  # Remove tags from transcriptions
  sed -i 's/ \[[^\[]*\]//g' data/text/transcriptions_word.txt

  # Remove lines without transcription
  gawk -i inplace 'NF>1{print}' data/text/transcriptions_word.txt

  sed -i "s/\!print/ \!print/g" data/text/transcriptions_word.txt
  # Expand abbreviations

  cat << EOF> data/text/abbreviations.txt 
SSW SSXW
NBE NxE NXE
NEBN NExN NEXN
NEBE KEBE NExE NEXE
EBN ExN EXN
EBS ExS EXS
SEBE SExE SEXE
SEBS SExS SEXS
SBE SxE SXE
SBW SxW SXW
SWBS SWxS SWXS
SWBW SWxW SWXW
WBS WxS WXS
WBN WxN WXN WBW
NNBN NWBW NWxW NWXW
NWBN NWxN NWXN
NBW NxW NXW
NNE1/2E NNEXE
S1/2E SB1/2E Sb1/2E Sx1/2E SX1/2E
S3/4E SB3/4E Sb3/4E Sx3/4E SX3/4E
SBE1/2E SxE1/2E SXE1/2E
SBE3/4E SxE3/4E SXE3/4E
S1/2E SE1/2 SXE1/02
S3/4E SXE3/4
NIMB.STR STR.NIMB
CIR.CUM CIRCUM CIR.CUM SIR.CUM CIR,CUM CIR.CIM CIR.SUM
CIR.STR CIR.STR SIR.STR CIR.SRT
CUM.STR CUM-STR CUM.STR STR.CUM.STR CUN.STR CUR.STR
NIMB NIMBS NIMB.
STR STRR
CIR CIS CIR2
ARCTIC ARTIC
NOON NOONN
FROM FRON
HERALD HERAL
DURING DURINT
REMAINING REMAINIGN
P.M. PM PM.
10THS. 10THMS. 10THS
EOF

  gawk -i inplace -vvocab=./data/text/abbreviations.txt '
    BEGIN{
      while(getline<vocab){
        for(i=2;i<=NF;i++){
            d[$i]=$1
            d["["$i"]"]="["$1"]"
            d["["$i]="["$1
            d[$i"]"]=$1"]"
        };
      }
    }{
      a=$1;
      for(i=2;i<=NF;i++){
        if ($i in d){
          a=a" "d[$i]
        }else{
          a=a" "$i
        }
        
      };
      print a
    }' data/text/transcriptions_word.txt

  sed -i "s/ \!print/\!print/g" data/text/transcriptions_word.txt
  sed -i "s/\(table.*\) \"/\1 <idem>/g" data/text/transcriptions_word.txt
  sed -i "s/\(table.*\) \"/\1 <idem>/g" data/text/transcriptions_word.txt
  sed -i "s/\(table.*\) \"/\1 <idem>/g" data/text/transcriptions_word.txt
  sed -i "s/\(table.*\) \"/\1 <idem>/g" data/text/transcriptions_word.txt
  sed -i "s/\(table.*\) \"/\1 <idem>/g" data/text/transcriptions_word.txt
  sed -i "s/\(table.*\) \"/\1 <idem>/g" data/text/transcriptions_word.txt
  sed -i "s/\(table.*\) \"/\1 <idem>/g" data/text/transcriptions_word.txt

  # Add !print tag in printed words that finish with a separator
  gawk -i inplace '{a=$1;$1="";$0=gensub(/([:;,.]!print)/,"!print\\1 ","g", $0); print a" "$0}' data/text/transcriptions_word.txt

  # Prepare char level transcriptions
    cat data/text/transcriptions_word.txt | \
      awk '{
        printf("%s <space>", $1);
        for(i=2;i<=NF;++i) {
          for(j=1;j<=length($i);++j)
            printf(" %s", substr($i, j, 1));
          if (i < NF) printf(" <space>");
        }
        printf(" <space> \n");
      }'  > data/text/transcriptions_char.txt
    sed -i 's/< d e c i m a l >/<decimal>/g' data/text/transcriptions_char.txt
    sed -i 's/< i d e m >/<idem>/g' data/text/transcriptions_char.txt
    sed -i 's/\! p r i n t/\!print/g' data/text/transcriptions_char.txt
    sed -i 's/\! b l a n k/\!blank/g' data/text/transcriptions_char.txt

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi

if [ "$stage" -le 1 ]; then
  echo "########################################"
  echo "# Extracting the CurvatureCorrectionExtractor features"
  echo "########################################"

  [ -d logs ] || mkdir logs
  TMPD=/tmp
  np=3
  work="./data/feats/"
  log_file="./logs/HisClima_feats_extraction.log"

  echo "CurvatureCorrectionExtractor extraction: "`date` | tee -a "${log_file}"
  [ -d ${work} ] && rm -r ${work}
  mkdir ${work}

  for page in $(find ./GT/ -name "*.xml" ); do
    echo $page
    gawk '{if($0~"<TableCell"){ getline; }else{ if($0~"CornerPts") getline; else{ if($0~"</TableCell") getline; else print $0}}}' "$page" | sed 's/TableRegion/TextRegion/g' | sed 's/TableCell/TextRegion/g'  > /tmp/$(basename "$page")
    (
    python3 "${CurvatureCorrectionExtractor_PATH}/curvatureCorrectionExtractor.py" /tmp/$(basename "$page") $(dirname $(dirname "$page"))/$(basename "$page" .xml).jpg ${work}/ 1 0.2 0 0 0.4 0.05 0 0 BLANK
      n_xml=$(grep '<TextLine' ${page} | wc -l)
      n_feats=$(find ${work}/ -name "*$(basename "$page" .xml)*png"| wc -l)
      n_lines=$n_feats # We are not extracting the raw lines
      echo `date`": File ID: $(basename $page .xml), \
      lines in xml: $n_xml, \
      extracted features: $n_feats \
      $([ $n_xml == $n_feats ] && \
      echo $([ $n_feats == $n_lines ] && echo " ; Correct" || \
      echo " ; ERROR in feature extraction") || echo " ; ERROR in line extraction")"
    ) &>> "${log_file}" &
    bkg_pids+=("$!");
    ## Wait for jobs to finish when number of running jobs = number of processors
    if [ "${#bkg_pids[@]}" -eq "$np" ]; then
      for n in $(seq 1 "${#bkg_pids[@]}"); do
          wait "${bkg_pids[n-1]}" || (
          echo "Failed image processing:" >&2 && cat "$TMPD/$[n-1]" >&2 && exit 1;
          );
      done;
      bkg_pids=();
    fi;
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 2 ]; then
  echo "########################################"
  echo "# Prepare the partitions lists and transcriptions"
  echo "########################################"
  [ -d data/lists ] || mkdir -p data/lists
  [ -d data/feats_0 ] || mkdir -p data/feats_{0,1}

  #find ./data/feats/ -name "*png" > data/lists/feats.lst
  for partition in "train" "val" "test"; do
    while read f; do
      grep  "${f}" data/lists/feats.lst;
    done < ./GT/PARTITIONS/${partition}.lst | sort -k1 | tee data/lists/${partition}_feats.lst | xargs -n1 basename | sed 's/\.png//' > data/lists/${partition}.lst
    grep -f data/lists/${partition}.lst data/text/transcriptions_word.txt | sort -k1 > data/text/transcriptions_${partition}_word.txt
    grep -f data/lists/${partition}.lst data/text/transcriptions_char.txt | sort -k1 > data/text/transcriptions_${partition}_char.txt
    for page in "0" "1"; do
      while read f; do
        grep  "${f}.${page}" data/lists/feats.lst;
      done < ./GT/PARTITIONS/${partition}.lst | sort -k1 | tee data/lists/${partition}_feats_${page}.lst | xargs -n1 basename | sed 's/\.png//' > data/lists/${partition}_${page}.lst

      while read f; do
        cp "${f}" "data/feats_${page}/";
      done < data/lists/${partition}_feats_${page}.lst 

      while read f; do
        grep  "${f}.${page}" data/text/transcriptions_${partition}_word.txt;
      done < ./GT/PARTITIONS/${partition}.lst | sort -k1 > data/text/transcriptions_${partition}_word_${page}.txt;
      while read f; do
        grep  "${f}.${page}" data/text/transcriptions_${partition}_char.txt;
      done < ./GT/PARTITIONS/${partition}.lst | sort -k1 > data/text/transcriptions_${partition}_char_${page}.txt;
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi  
fi


if [ "$stage" -le 3 ]; then
  echo "########################################"
  echo "# Obtaining the set of symbols"
  echo "########################################"

  for page in "0" "1"; do
    for partition in train val; do
      cat data/text/transcriptions_${partition}_char_${page}.txt | awk '{if(NF>1) print $0}' | cut -f 2- -d\  | tr \  \\n;
    done | sort -u -V | awk 'BEGIN{N=0; printf("%-12s %d\n", "<eps>", N++);} NF==1{printf("%-12s %d\n", $1, N++);}' > data/lists/symbols_${page}.lst
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 4 ]; then
  echo "########################################"
  echo "# Remove samples with small images"
  echo "########################################"
  np=6
  for f in $(cat data/lists/{train,val,test}_feats.lst); do
    (
      sample=$(basename $f .png)
      size=$(file ${f} | awk '{split($7,a,",");print $5" "a[1]}')
      x=$(echo $size | awk '{print $1}')
      y=$(echo $size | awk '{print $2}')
      echo $sample" "$x" "$y
      if [ "$x" -le "10" ] || [ "$y" -le "10" ]; then
        echo "To remove: "$sample;
        sed -i "/${sample}/d" data/text/*_{train,val,test}_{word,char}.txt;
      fi
    ) &>> logs/removing_small_samples.log &
    bkg_pids+=("$!");
    ## Wait for jobs to finish when number of running jobs = number of processors
    if [ "${#bkg_pids[@]}" -eq "$np" ]; then
      for n in $(seq 1 "${#bkg_pids[@]}"); do
          wait "${bkg_pids[n-1]}" || (
          echo "Failed image processing:" >&2 && cat "$TMPD/$[n-1]" >&2 && exit 1;
          );
      done;
      bkg_pids=();
    fi
  done

  for partition in "train" "val" "test"; do
    awk '{print $1}' data/text/transcriptions_${partition}_word.txt > data/lists/${partition}.lst
    grep -f data/lists/${partition}.lst data/lists/feats.lst > data/lists/${partition}_feats.lst
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 5 ]; then
  echo "########################################"
  echo "# Create and train the HTR models with the PyLaia_JA"
  echo "########################################"

#   conda activate PyLaia_JA
  batch_size=10;
  cnn_activations="LeakyReLU LeakyReLU LeakyReLU LeakyReLU";
  cnn_dilation="1 1 1 1";
  cnn_kernel_size="3 3 3 3";
  cnn_num_features="16 32 48 64";
  cnn_pool_size="1 1 0 0";
  cnn_stride="1 1 1 1";
  cnn_dropout="0.2 0.2 0.2 0.2";
  learning_rate=0.0003;
  max_non_decreasing_epochs=50;
  rnn_units=256;
  rnn_layers=4;
  height=128;
  use_distortions=true;
  cnn_batchnorm="true true true true";

  for page in "0"; do
    img_dirs="data/feats_${page}/"
    output_dir="work_${page}"
    [ -d $output_dir ] || mkdir -p $output_dir

    [ -f ${output_dir}/model ] || pylaia-htr-create-model \
      --logging_also_to_stderr info \
      --logging_file "${output_dir}/train.log" \
      --logging_level info \
      --logging_overwrite true \
      --train_path "${output_dir}" \
      --cnn_activations ${cnn_activations} \
      --cnn_dilation ${cnn_dilation} \
      --cnn_kernel_size ${cnn_kernel_size} \
      --cnn_num_features ${cnn_num_features} \
      --cnn_poolsize ${cnn_pool_size} \
      --cnn_stride ${cnn_stride} \
      --cnn_batchnorm ${cnn_batchnorm} \
      --cnn_dropout ${cnn_dropout} \
      --rnn_layers "$rnn_layers" \
      --rnn_units "$rnn_units" \
      --rnn_dropout 0.5 \
      --lin_dropout 0.5 \
      --use_masked_conv false \
      -- \
      1 data/lists/symbols_${page}.lst;

    pylaia-htr-train-ctc \
      --gpu 1 \
      --logging_also_to_stderr info \
      --logging_file "${output_dir}/train.log" \
      --logging_level info \
      --logging_overwrite false \
      --train_path "${output_dir}" \
      --learning_rate "${learning_rate}" \
      --delimiters "<space>" \
      --max_nondecreasing_epochs "${max_non_decreasing_epochs}" \
      --save_checkpoint_interval 10 \
      --batch_size "${batch_size}" \
      --show_progress_bar true \
      --use_distortions "${use_distortions}" \
      -- \
      data/lists/symbols_${page}.lst \
      ${img_dirs} \
      data/text/transcriptions_{train,val}_char_${page}.txt;
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 6 ]; then
  echo "########################################"
  echo "# CTC decode for val and test partitions"
  echo "########################################"
#   conda activate PyLaia_JA

  for page in "0" "1"; do
    for partition in "val" "test"; do
    img_dirs="data/feats_${page}/"
    output_dir="work_${page}"
    [ ! -d ${output_dir}/results ] && mkdir -p ${output_dir}/results
    pylaia-htr-decode-ctc \
      --print_args True \
      --train_path "${output_dir}" \
      --model_filename model \
      --logging_level info \
      --gpu 0 \
      --use_letters \
      --logging_also_to_stderr info \
      --logging_file logs/${partition}_ctc-decoding.log \
      data/lists/symbols_${page}.lst \
      ${img_dirs} \
      data/lists/${partition}_${page}.lst | sed "s/\[.//" | sed "s/.\]//" | sed "s/.\, ./ /g" | sort -V > ${output_dir}/results/${partition}_ctc_char.txt

      gawk '{
        printf("%s ", $1);
        for (i=2;i<=NF;++i) {
          if ($i == "<space>")
            printf(" ");
          else
            printf("%s", $i);
        }
        printf("\n");
      }' ${output_dir}/results/${partition}_ctc_char.txt | tr -s ' ' | sed "s|''|\"|g" | sed 's/ $//' > ${output_dir}/results/${partition}_ctc_word.txt
    done
  done
  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 7 ]; then
  echo "########################################"
  echo "# Evaluate ctc decoding"
  echo "########################################"

  for page in "0" "1"; do
    for partition in "val" "test"; do
      sort -k1 data/text/transcriptions_${partition}_char_${page}.txt > /tmp/char.ref
      sort -k1 data/text/transcriptions_${partition}_word_${page}.txt > /tmp/word.ref
      sort -k1 work_${page}/results/${partition}_ctc_char.txt > /tmp/char.hyp
      sort -k1 work_${page}/results/${partition}_ctc_word.txt > /tmp/word.hyp
    
      cat /tmp/char.hyp | awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' > /tmp/char_clean.hyp
      cat /tmp/char.ref | awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' > /tmp/char_clean.ref

      cat /tmp/word.hyp | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | sed 's/ \!blank//g' > /tmp/word_clean.hyp
      cat /tmp/word.ref | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | sed 's/ \!blank//g' > /tmp/word_clean.ref

      cer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/char_clean.hyp" "ark:/tmp/char_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      wer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/word_clean.hyp" "ark:/tmp/word_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      echo -e "$page\t$partition\tGlobal\t CER=$cer\t WER=$wer"

      cat /tmp/char.ref | sed 's/ <space>[^!]*<space>/ <space>/g' | awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' > /tmp/char_clean.ref
      cat /tmp/char.hyp | sed 's/ <space>[^!]*<space>/ <space>/g'| awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' > /tmp/char_clean.hyp

      cat /tmp/word.hyp | sed 's/ [^!]*\ / /g' | sed 's/ [^!]*$/ /g'  | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' | sed 's/ \! blank//g'  > /tmp/word_clean.hyp
      cat /tmp/word.ref | sed 's/ [^!]*\ / /g' | sed 's/ [^!]*$/ /g' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' | sed 's/ \! blank//g'  > /tmp/word_clean.ref

      cer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/char_clean.hyp" "ark:/tmp/char_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      wer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/word_clean.hyp" "ark:/tmp/word_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      echo -e "$page\t$partition\tprint\t CER=$cer\t WER=$wer"

      cat /tmp/char.hyp | sed 's/ <space>[^<]*\!print//g' | sed 's/ \!blank <space>//g' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}'| awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' > /tmp/char_clean.hyp
      cat /tmp/char.ref | sed 's/ <space>[^<]*\!print//g' | sed 's/ \!blank <space>//g' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}'| awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' > /tmp/char_clean.ref

      cat /tmp/word.hyp | sed 's/ [^ ]*\!print//g' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' | sed 's/ \! blank//g' > /tmp/word_clean.hyp
      cat /tmp/word.ref | sed 's/ [^ ]*\!print//g' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' | sed 's/ \! blank//g' > /tmp/word_clean.ref

      cer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/char_clean.hyp" "ark:/tmp/char_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      wer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/word_clean.hyp" "ark:/tmp/word_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      echo -e "$page\t$partition\tmanuscript\t CER=$cer\t WER=$wer"

      cat /tmp/char.hyp | sed 's/<decimal>//g' | sed 's/<space>//g' | awk '{a=$1; for (i=2;i<=NF;i++){if ($i ~/\!.*/) {a=a" "$i}}; print a}' | tr -s ' ' | sed 's/ $//' > /tmp/tag_clean.hyp
      cat /tmp/char.ref | sed 's/<decimal>//g' | sed 's/<space>//g' | awk '{a=$1; for (i=2;i<=NF;i++){if ($i ~/\!.*/) {a=a" "$i}}; print a}' | tr -s ' ' | sed 's/ $//' > /tmp/tag_clean.ref

      ter=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/tag_clean.hyp" "ark:/tmp/tag_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      echo -e "$page\t$partition\ttags ER=$ter"

    done | column -t | tee logs/ctc_val_test_stats_${page}.log
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 8 ]; then
  echo "########################################"
  echo "# GET Confidence Matrix for val and test partitions"
  echo "########################################"
#   conda activate PyLaia_JA
  for page in "0" "1"; do
    for partition in "val" "test"; do
      img_dirs="data/feats_${page}/"
      output_dir="work_${page}"
      [ -d ${output_dir}/results ] || mkdir -p ${output_dir}/results

      pylaia-htr-netout \
        --print_args True \
        --train_path "${output_dir}" \
        --model_filename model \
        --logging_level info \
        --logging_also_to_stderr info \
        --show_progress_bar \
        --gpu 0 \
        --logging_file logs/${partition}_netout_${page}.log \
        --batch_size 15 \
        --output_transform log_softmax \
        --output_matrix ${output_dir}/results/${partition}_matrix.ark \
        ${img_dirs} \
        data/lists/${partition}_${page}.lst;
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 9 ]; then
  echo "########################################"
  echo "# Prepare the LM"
  echo "########################################"

  for page in "0" "1"; do
    for order in $(seq 3 15); do
      output_dir=LM/${page}/$order
      [ -d ${output_dir} ] && rm -r ${output_dir}
      mkdir -p ${output_dir}
      sed '/eps/d' data/lists/symbols_${page}.lst > /tmp/symbols.lst
      for label in "\!print" ; do
        sed -i "/$label/d" /tmp/symbols.lst
        grep $label data/lists/symbols_${page}.lst
      done > data/lists/labels_${page}.lst
      bash gen_LM.sh ${output_dir} /tmp/symbols.lst data/lists/labels_${page}.lst <(cat data/text/transcriptions_{train,val}_char_${page}.txt) $order
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 10 ]; then
  echo "########################################"
  echo "# Find the optimal parameters for decoding with LM"
  echo "########################################"
  for page in "0" "1"; do
    python3 latgen_optimization.py ${page} | tee logs/latgen_optimization_${page}.log
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 11 ]; then
  echo "########################################"
  echo "# Get lattices with LM for GT val and test"
  echo "########################################"
  utils=./utils/

  for page in "1"; do
    if [ $page -eq 0 ]; then
      asf=891.93                             # acoustic scale factor
      beam_search=9346.24                    # beam search
      order=3
    else
      asf=3.75                               # acoustic scale factor
      beam_search=20.93                      # beam search
      order=4
    fi

    lattice_beam=40                          # lattice generation beam
    max_active=2147483647

    output_dir="work_${page}"
    LM="LM/${page}/${order}/LM"

    for partition in "val" "test"; do
      LAT_FILE=${output_dir}/decode/${partition}.gz
      DECODE=${output_dir}/decode

      [ -d $DECODE ] || mkdir -p $DECODE
    
      echo "Generating lattices: $LAT_FILE asf: $asf beam: ${beam_search} order: $order"
      latgen-faster-mapped --verbose=2 --allow-partial=true \
        --acoustic-scale=${asf} --max-active=${max_active} \
        --beam=${beam_search} --lattice-beam=${lattice_beam}\
        ${LM}/new.mdl \
        ${LM}/HCLG.fst ark:${output_dir}/results/${partition}_matrix.ark \
        "ark:|gzip -c > $LAT_FILE" \
        "ark,t:| "${utils}"/int2sym.pl -f 2- ${LM}/words.txt > ${output_dir}/results/${partition}_latgen_char.txt" 2> logs/${partition}_latgen_${page}.log

      gawk '{
        printf("%s ", $1);
        for (i=2;i<=NF;++i) {
          if ($i == "<space>")
	    printf(" ");
          else
	    printf("%s", $i);
        }
        printf("\n");
      }' ${output_dir}/results/${partition}_latgen_char.txt | tr -s ' ' | sed "s|''|\"|g" | sed 's/ $//' > ${output_dir}/results/${partition}_latgen_word.txt

    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 12 ]; then
  echo "########################################"
  echo "# Add best latgen hypothesis to the xml page files"
  echo "########################################"
  
  for page in "0" "1"; do
    output_dir="work_${page}"
    for partition in "val" "test"; do
      transcriptions=${output_dir}/results/${partition}_latgen_word.txt
      sed 's/<decimal>/\./g' $transcriptions | sed 's/\!blank//g' > /tmp/transcriptions.txt
      transcriptions=/tmp/transcriptions.txt
      [ ! -d ${output_dir}/results/page/${partition} ] && mkdir -p ${output_dir}/results/page/${partition}
      while read f; do
        [ -f "data/page/${page}/${f}-${page}.xml" ] && page_id="${f}-${page}"
        [ -f "data/page/${page}/${f}_${page}.xml" ] && page_id="${f}_${page}"

        f="data/page/${page}/${page_id}.xml"
        echo "$f ->  $page_id"

        sed 's/\!print//g' $f | tidy -xml -w 0 -i - | \
          awk '{if(($0!~"TextEquiv>")&&($0!~"Unicode>")) print $0}' | \
          awk -v page=$page_id -v file=$transcriptions 'BEGIN{
                while(( getline line<file) > 0 ) {
                  split(line,a,"\.");
                  if(a[1] == page){
                    st = index(a[3],"\ ");
                    id = "\""substr(a[3],0,st-1)"\""
                    st = index(line,"\ ");
                    text = substr(line,st+1)
                    transcriptions[id]=text;
                  }
                }
              }{
                if ($1=="<TextLine"){
                  split($2,line_id,"=");
                  print($0)
                  print("         <TextEquiv>")
                  print("           <Unicode>"transcriptions[line_id[2]]"</Unicode>")
                  print("         </TextEquiv>")
              }else{
                print $0
                }
              }' | tidy -xml -w 0 -i - > ${output_dir}/results/page/${partition}/${page_id}.xml
      done < ./GT/PARTITIONS/${partition}.lst
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 13 ]; then
  echo "########################################"
  echo "# Evaluate lattice generation"
  echo "########################################"
  
  for page in "0" "1"; do
    for partition in "val" "test"; do
      sort -k1 data/text/transcriptions_${partition}_char_${page}.txt > /tmp/char.ref
      sort -k1 data/text/transcriptions_${partition}_word_${page}.txt > /tmp/word.ref
      sort -k1 work_${page}/results/${partition}_latgen_char.txt > /tmp/char.hyp
      sort -k1 work_${page}/results/${partition}_latgen_word.txt > /tmp/word.hyp

      cat /tmp/char.hyp | awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' > /tmp/char_clean.hyp
      cat /tmp/char.ref | awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' > /tmp/char_clean.ref

      cat /tmp/word.hyp | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | sed 's/\! blank//g' > /tmp/word_clean.hyp
      cat /tmp/word.ref | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | sed 's/\! blank//g' > /tmp/word_clean.ref

      cer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/char_clean.hyp" "ark:/tmp/char_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      wer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/word_clean.hyp" "ark:/tmp/word_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      echo -e "$page\t$partition\tGlobal\t CER=$cer\t WER=$wer"

      cat /tmp/char.ref | sed 's/ <space>[^!]*<space>/ <space>/g' | awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' > /tmp/char_clean.ref
      cat /tmp/char.hyp | sed 's/ <space>[^!]*<space>/ <space>/g'| awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' > /tmp/char_clean.hyp

      cat /tmp/word.hyp | sed 's/ [^!]*\ / /g' | sed 's/ [^!]*$/ /g' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' | sed 's/\! blank//g' > /tmp/word_clean.hyp
      cat /tmp/word.ref | sed 's/ [^!]*\ / /g' | sed 's/ [^!]*$/ /g' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' | sed 's/\! blank//g' > /tmp/word_clean.ref

      cer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/char_clean.hyp" "ark:/tmp/char_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      wer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/word_clean.hyp" "ark:/tmp/word_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      echo -e "$page\t$partition\tprint\t CER=$cer\t WER=$wer"

      cat /tmp/char.hyp | sed 's/ <space>[^<]*\!print//g' | sed 's/ \!blank <space>//g' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}'| awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' > /tmp/char_clean.hyp
      cat /tmp/char.ref | sed 's/ <space>[^<]*\!print//g' | sed 's/ \!blank <space>//g' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}'| awk '{if($2=="<space>")$2=""; if($NF=="<space>")$NF="";print $0}' > /tmp/char_clean.ref

      cat /tmp/word.hyp | sed 's/ [^ ]*\!print//g' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' | sed 's/\! blank//g' > /tmp/word_clean.hyp
      cat /tmp/word.ref | sed 's/ [^ ]*\!print//g' | sed 's/<decimal>/\./g' | sed 's/\!manuscript//g' | sed 's/\!print//g' |  awk '{a=$1;$1="";$0=gensub(/([[:punct:]])/," \\1 ","g", $0); print a" "$0}' | sed 's/\([0-9]\) \. \([0-9]\)/\1\.\2/g' | tr -s ' ' | sed 's/ $//' | awk '{if (NF>1) print $0}' | sed 's/\! blank//g' > /tmp/word_clean.ref

      cer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/char_clean.hyp" "ark:/tmp/char_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      wer=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/word_clean.hyp" "ark:/tmp/word_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      echo -e "$page\t$partition\tmanuscript\t CER=$cer\t WER=$wer"

      cat /tmp/char.hyp | sed 's/<decimal>//g' | sed 's/<space>//g' | awk '{a=$1; for (i=2;i<=NF;i++){if ($i ~/\!.*/) {a=a" "$i}}; print a}' | tr -s ' ' | sed 's/ $//' > /tmp/tag_clean.hyp
      cat /tmp/char.ref | sed 's/<decimal>//g' | sed 's/<space>//g' | awk '{a=$1; for (i=2;i<=NF;i++){if ($i ~/\!.*/) {a=a" "$i}}; print a}' | tr -s ' ' | sed 's/ $//' > /tmp/tag_clean.ref

      ter=$(compute-wer-bootci --print-args=false --mode=present "ark:/tmp/tag_clean.hyp" "ark:/tmp/tag_clean.ref" | awk '{print $3" ["$8" "$9"]"}' | head -1)
      echo -e "$page\t$partition\ttags ER=$ter"
    done | column -t | tee logs/latgen_val_test_stats_${page}.log
  done 

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 14 ]; then
  echo "########################################"
  echo "# Evaluate lattice density"
  echo "########################################"

  for page in "0" "1"; do
    for partition in "val" "test"; do
      lattice-depth "ark: gunzip -c work_${page}/decode/${partition}.gz|"
    done 2> logs/latgen_val_test_density_${page}.log
    cat logs/latgen_val_test_density_${page}.log
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


####################
# DLA TEST
####################

if [ "$stage" -le 15 ]; then
  echo "########################################"
  echo "# Get sample list for DLA test"
  echo "########################################"

  for page_side in "0" "1"; do
    img_dirs="data/dla_feats_${page_side}/"
    [ -d ${img_dirs} ] || mkdir -p ${img_dirs}
    cd $img_dirs

    while read page; do
      cp "../../../DLA/results/${page_side}/test/feats/${page}"*/*png ./
    done < ../../../GT/PARTITIONS/test.lst
    cd -
    find $img_dirs -name '*.png' -printf "%f\n" | xargs -n1  basename | sed 's/\.png//' | sort > data/lists/dla_test_${page_side}.lst
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 16 ]; then
  echo "########################################"
  echo "# CTC Decode DLA test"
  echo "########################################"
  #   conda activate PyLaia_JA

  for page in "0" "1"; do
    output_dir="work_${page}"
    [ ! -d ${output_dir}/results ] && mkdir -p ${output_dir}/{results,logs}
    img_dirs="data/dla_feats_${page}/"

    pylaia-htr-decode-ctc \
      --print_args True \
      --batch_size 5 \
      --train_path "work_${page}" \
      --model_filename model \
      --logging_level info \
      --gpu 1 \
      --use_letters \
      --logging_also_to_stderr info \
      --logging_file logs/dla_test_ctc-decoding_${page}.log \
      data/lists/symbols_${page}.lst \
      ${img_dirs} data/lists/dla_test_${page}.lst | sed "s/\[.//" | sed "s/.\]//" | sed "s/.\, ./ /g" | sort -V > ${output_dir}/results/dla_test_ctc_char.txt

    gawk '{
        printf("%s ", $1);
        for (i=2;i<=NF;++i) {
          if ($i == "<space>")
            printf(" ");
          else
            printf("%s", $i);
        }
        printf("\n");
    }' ${output_dir}/results/dla_test_ctc_char.txt | tr -s ' ' | sed "s|''|\"|g" | sed 's/ $//' > ${output_dir}/results/dla_test_ctc_word.txt
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 17 ]; then
  echo "########################################"
  echo "# GET Confidence Matrix for DLA test"
  echo "########################################"
#   conda activate PyLaia_JA

  for page in "0" "1"; do
    output_dir="work_${page}"
    [ ! -d ${output_dir}/results ] && mkdir -p ${output_dir}/results
    img_dirs="data/dla_feats_${page}/"

    pylaia-htr-netout \
      --print_args True \
      --train_path "work_${page}" \
      --model_filename model \
      --logging_level info \
      --logging_also_to_stderr info \
      --show_progress_bar \
      --gpu 1 \
      --logging_file logs/dla_test_netout_${page}.log \
      --batch_size 5 \
      --output_transform log_softmax \
      --output_matrix ${output_dir}/results/dla_test_matrix.ark \
      ${img_dirs} \
      data/lists/dla_test_${page}.lst;
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 18 ]; then
  echo "########################################"
  echo "# Get lattices with LM for DLA test"
  echo "########################################"

  utils=./utils/

  for page in "0" "1"; do
    if [ $page -eq 0 ]; then
      asf=891.93                             # acoustic scale factor
      beam_search=9346.24                    # beam search
      order=3
    else
      asf=3.75                               # acoustic scale factor
      beam_search=20.93                      # beam search
      order=4
    fi
    lattice_beam=60                          # lattice generation beam 
    max_active=2147483647

    output_dir="work_${page}"
    LM="LM/${page}/${order}/LM"

    LAT_FILE=${output_dir}/decode/dla_test.gz
    DECODE=${output_dir}/decode

    [ -d $DECODE ] || mkdir -p $DECODE

    echo "Generating lattices: $LAT_FILE"
    latgen-faster-mapped --verbose=2 --allow-partial=true \
      --acoustic-scale=${asf} --max-active=${max_active} \
      --beam=${beam_search} --lattice-beam=${lattice_beam}\
      ${LM}/new.mdl \
      ${LM}/HCLG.fst ark:${output_dir}/results/dla_test_matrix.ark \
      "ark:|gzip -c > $LAT_FILE" \
      "ark,t:| "${utils}"/int2sym.pl -f 2- ${LM}/words.txt > ${output_dir}/results/dla_test_latgen_char.txt" 2> logs/dla_test_latgen_${page}.log

    gawk '{
        printf("%s ", $1);
        for (i=2;i<=NF;++i) {
          if ($i == "<space>")
            printf(" ");
          else
            printf("%s", $i);
        }
        printf("\n");
      }' ${output_dir}/results/dla_test_latgen_char.txt | tr -s ' ' | sed 's/ $//' > ${output_dir}/results/dla_test_latgen_word.txt
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 19 ]; then
  echo "########################################"
  echo "# Add best latgen hypothesis to the xml page files for DLA test"
  echo "########################################"
  
  output_dir="work"
  transcriptions=${output_dir}/results/dla_test_latgen_word.txt
  sed 's/<decimal>/\./g' $transcriptions > /tmp/transcriptions.txt
  transcriptions=/tmp/transcriptions.txt
  [ ! -d ${output_dir}/results/page/dla_test ] && mkdir -p ${output_dir}/results/page/dla_test
  while read f; do
    page_id=$f
    f="../DLA/results/test/page/${f}.xml"
    echo "$f ->  $page_id"

    awk -v page=$page_id -v file=$transcriptions 'BEGIN{
            while(( getline line<file) > 0 ) {
              split(line,a,"\.");
              if(a[1] == page){
                  st = index(a[3],"\ ");
                  id = "\""substr(a[3],0,st-1)"\""
                  st = index(line,"\ ");
                  text = substr(line,st+1)
                  transcriptions[id]=text;
              }
            }
          }{
            if ($1=="<TextLine"){
              split($2,line_id,"=");
              print($0)
              print("         <TextEquiv>")
              print("           <Unicode>"transcriptions[line_id[2]]"</Unicode>")
              print("         </TextEquiv>")
          }else{
            print $0
            }
          }' $f | tidy -xml -w 0 -i - > ${output_dir}/results/page/dla_test/${page_id}.xml
  done < ../PARTITIONS/test.lst

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 20 ]; then
  echo "########################################"
  echo "# Evaluate lattice density for DLA test"
  echo "########################################"
  
  for page in "0" "1"; do
    lattice-depth "ark: gunzip -c work_${page}/decode/dla_test.gz|" 2> logs/latgen_dla_test_density_${page}.log
    cat logs/latgen_dla_test_density_${page}.log
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 21 ]; then
  echo "########################################"
  echo "# Get textual corpus statistics"
  echo "########################################"
  iconv -f utf8 data/text/transcriptions.txt | sed 's/ \[[^\[]*\]//g' | sed 's/ \!blank//g' > /tmp/text_global
  [ -f /tmp/global.lst ] && rm /tmp/global.lst
  for partition in "train" "val" "test"; do
    grep -f data/lists/${partition}.lst /tmp/text_global > /tmp/text_${partition}
    cp GT/PARTITIONS/${partition}.lst /tmp/${partition}.lst
    cat GT/PARTITIONS/${partition}.lst >> /tmp/global.lst
  done


  (
  for partition in "global" "train" "val" "test"; do
    echo "Partition: ${partition}"
    echo "#####################################################"
    echo "Number of pages $(wc -l /tmp/${partition}.lst | awk '{print $1 * 2}')"
    echo "Total number of lines $(cat /tmp/text_${partition} | wc -l)"
    echo "Total number of running words $(awk '{$1=""; print $0}' /tmp/text_${partition} | sed -r '/^\s*$/d' |  wc -w)"
    echo "Total number of different words $(awk '{$1=""; print $0}' /tmp/text_${partition} | tr ' ' '\n' | sort -u | sed -r '/^\s*$/d'| wc -w)"
    echo "Total number of running chars $(awk '{$1=""; print $0}' /tmp/text_${partition} | tr ' ' '\n' | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | wc -c
  )"
    echo "Total number of different chars $(awk '{$1=""; print $0}' /tmp/text_${partition} | tr ' ' '\n' | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | tr -d '\n' |  grep -o . | sort -u | wc -l)"
    echo "#####################################################"
    
    echo "#####################################################"
    echo "Type of text: print"
    echo "Number of lines $(wc -l /tmp/text_${partition} | awk '{print $1}')"
    echo "Number of running words $(awk '{$1=""; print $0}' /tmp/text_${partition} | tr ' ' '\n' | sed -r '/^\s*$/d' | grep "\!print" |  wc -w)"
    echo "Number of different words $(awk '{$1=""; print $0}' /tmp/text_${partition} | tr ' ' '\n' | grep "\!print" | sort -u | sed -r '/^\s*$/d'| wc -w)"
    echo "Number of running chars $(awk '{$1=""; print $0}' /tmp/text_${partition} | tr ' ' '\n' | grep "\!print" | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | wc -c
  )"
    echo "Number of different chars $(awk '{$1=""; print $0}' /tmp/text_${partition} | tr ' ' '\n' | grep "\!print" | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | tr -d '\n' |  grep -o . | sort -u | wc -l)"
    echo "#####################################################"
    echo "#####################################################"
    echo "Type of text: manuscript"
    echo "Number of lines $(wc -l /tmp/text_${partition} | awk '{print $1}')"
    echo "Number of running words $(awk '{$1=""; print $0}' /tmp/text_${partition} | tr ' ' '\n' | sed -r '/^\s*$/d' | grep -v "\!print" |  wc -w)"
    echo "Number of different words $(awk '{$1=""; print $0}' /tmp/text_${partition} | tr ' ' '\n' | grep -v "\!print" | sort -u | sed -r '/^\s*$/d'| wc -w)"
    echo "Number of running chars $(awk '{$1=""; print $0}' /tmp/text_${partition} | tr ' ' '\n' | grep -v "\!print" | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | wc -c
  )"
    echo "Number of different chars $(awk '{$1=""; print $0}' /tmp/text_${partition} | tr ' ' '\n' | grep -v "\!print" | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | tr -d '\n' |  grep -o . | sort -u | wc -l)"
    echo "#####################################################"
    echo ""



    for page_type in "0" "1"; do
      if [ $page_type == "0" ]; then
        page_type_tag="TABLES"
      else
        page_type_tag="DESCRIPTIVE"
      fi
      grep "[-_]${page_type}\.t" /tmp/text_${partition} > /tmp/text_${page_type}
      echo "#####################################################"
      echo "Total type of page: ${page_type_tag}"
      echo "Number of pages $(wc -l /tmp/${partition}.lst | awk '{print $1}')"
      echo "Number of lines $(cat /tmp/text_${page_type} | wc -l)"
      echo "Number of running words $(awk '{$1=""; print $0}' /tmp/text_${page_type} | sed -r '/^\s*$/d'|  wc -w)"
      echo "Number of different words $(awk '{$1=""; print $0}' /tmp/text_${page_type} | tr ' ' '\n' | sort -u | sed -r '/^\s*$/d'| wc -w)"
      echo "Number of running chars $(awk '{$1=""; print $0}' /tmp/text_${page_type} | tr ' ' '\n' | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | wc -c
  )"
      echo "Number of different chars $(awk '{$1=""; print $0}' /tmp/text_${page_type} | tr ' ' '\n' | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | tr -d '\n' |  grep -o . | sort -u | wc -l)"
      echo "#####################################################"
      
      echo "#####################################################"
      echo "Type of page: ${page_type_tag}"
      echo "Type of text: print"
      echo "Number of lines $(wc -l /tmp/text_${page_type} | awk '{print $1}')"
      echo "Number of running words $(awk '{$1=""; print $0}' /tmp/text_${page_type} | tr ' ' '\n' | grep "\!print" | sed -r '/^\s*$/d' | wc -w)"
      echo "Number of different words $(awk '{$1=""; print $0}' /tmp/text_${page_type} | tr ' ' '\n' | grep "\!print" | sort -u | sed -r '/^\s*$/d'| wc -w)"
      echo "Number of running chars $(awk '{$1=""; print $0}' /tmp/text_${page_type} | tr ' ' '\n' | grep "\!print" | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | wc -c
  )"
      echo "Number of different chars $(awk '{$1=""; print $0}' /tmp/text_${page_type} | tr ' ' '\n' | grep "\!print" | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | tr -d '\n' |  grep -o . | sort -u | wc -l)"
      echo "#####################################################"
      
      echo "#####################################################"
      echo "Type of page: ${page_type_tag}"
      echo "Type of text: manuscript"
      echo "Number of lines $(wc -l /tmp/text_${page_type} | awk '{print $1}')"
      echo "Number of running words $(awk '{$1=""; print $0}' /tmp/text_${page_type} | tr ' ' '\n' | grep -v "\!print" | sed -r '/^\s*$/d' | wc -w)"
      echo "Number of different words $(awk '{$1=""; print $0}' /tmp/text_${page_type} | tr ' ' '\n' | grep -v "\!print" | sort -u | sed -r '/^\s*$/d'| wc -w)"
      echo "Number of running chars $(awk '{$1=""; print $0}' /tmp/text_${page_type} | tr ' ' '\n' | grep -v "\!print" | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | wc -c
  )"
      echo "Number of different chars $(awk '{$1=""; print $0}' /tmp/text_${page_type} | tr ' ' '\n' | grep -v "\!print" | sort -u | sed -r '/^\s*$/d' | sed 's/\!.*//' | tr -d '\n' |  grep -o . | sort -u | wc -l)"
      echo "#####################################################"
    done
    echo ""
  done
  ) > logs/Corpus.stats

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi
