#! /bin/bash

# Default values
stage=0
unique_stage=true

if [ $# -eq 0 ]; then
  echo "########################################"
  echo "Use: bash ${0##*/} [options]"
  echo "Options:"
  echo " -s Stage: [0: Data preparation,"
  echo "            1: Obtaining polygon coordinates,"
  echo "            2: Obtaining image sizes,"
  echo "            3: Producing probabilistic indexes,"
  echo "            4: Get index density,"
  echo "            5: Generating probabilistic index files for DEMO,"
  echo "            6: Index corrections,"
  echo "            7: Creating thumbnails,"
  echo "            8: Fix RP inconsistencies,"
  echo "            9: Set the main image for DEMO,"
  echo "           10: Obtain the index statistics,"
  echo "           11: Evaluate index]"
  echo " -u Unique stage: $unique_stage"
  echo "########################################"
  exit 0
fi

while getopts s:u: flag
do
  case "${flag}" in
    s) stage=${OPTARG};;
    u) unique_stage=${OPTARG};;
  esac
done

if [ "$stage" -le 0 ]; then
  echo "##########################"
  echo "Prepare data, page images, xml, lattices and words.txt file"
  echo "##########################"

  for page in "0" "1"; do
    for partition in "val" "test" "train"; do
      [ -d IMAGES/${page}/${partition} ] || mkdir -p IMAGES/${page}/${partition}
      cd ./IMAGES/${page}/${partition}/
      ln -s ../../../../DLA/data/${page}/${partition}/*jpg ./
      for f in *jpg; do
        echo $f; 
        gawk '{if($0~"<TableCell"){ getline; }else{ if($0~"CornerPts") getline; else{ if($0~"</TableCell") getline; else print $0}}}'  ../../../../DLA/data/${page}/${partition}/page/$(basename $f .jpg).xml  | sed 's/TableRegion/TextRegion/g' | sed 's/TableCell/TextRegion/g' | tidy -xml -i - > ./$(basename "$f" .jpg).xml
      done
      cd -
    done 

    [ -d IMAGES/${page}/dla_test ] || mkdir -p IMAGES/${page}/dla_test
    cd ./IMAGES/${page}/dla_test/
    ln -s ../../../../DLA/data/${page}/test/*jpg ./
    ln -s ../../../../DLA/results/${page}/test/page/*xml ./
    cd -

    ln -s ../HTR/LM/${page}/4/LM/prepare_G/words.txt words_${page}.txt
    [ -d LATs/${page} ] || mkdir -p LATs/${page}
    cd LATs/${page}/
    ln -s ../../../HTR/work_${page}/decode/*.gz ./
    cd -
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 1 ]; then
  echo "##########################"
  echo "Obtaining polygon coordinates of lines for each image within each folder"
  echo "##########################"

  # It requires "xmlstarlet" command (apt-get install xmlstarlet)
  [ -d Line-Coords ] || mkdir -p Line-Coords/{0,1}
  [ -d logs ] || mkdir logs

  for page in "0" "1"; do
    for d in ./IMAGES/${page}/*; do
      D=$(basename $d); 
      echo "Processing $D $page ..." >&2;
      for f in $d/*.xml; do
        xmlstarlet sel -t -m '//_:TextLine' -v ../../@imageFilename -o ' ' -v ../@id  -o '.' -v @id -o " " -v _:Coords/@points -n $f || echo $f >> ./logs/Error-LineCoord_${page}.log;
      done | sed -r "s/\.jpg//" > Line-Coords/${page}/$D.crd;
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 2 ]; then
  echo "##########################"
  echo "Obtaining sizes of images within each folder"
  echo "##########################"
  # It requires "identify" command from imagemagick package

  for page in "0" "1"; do
    for d in ./IMAGES/${page}/*; do
      D=$(basename $d); 
      echo "Processing $D $page ...";
      for f in $d/*.jpg; do
        identify -format "%f %W %H\n" $f | sed -r "s/\.jpg//";
      done > Line-Coords/${page}/$D.inf;
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 3 ]; then
  echo "##########################"
  echo "Producing Probabilistic Indexes"
  echo "##########################"
  # This requires "lattice-char-index-position" command 

  # For each folder and corresponding .cdr file in line_coords directory,
  # this creates an auxiliary GT file containing bounding boxes of line 
  # polygon coordinates in .cdr file. This file is used in the mapping step.

  [ -d indx ] || mkdir -p indx/{0,1}

  for page in "0" "1"; do
    for b in LATs/${page}/*.gz; do
      separators=$(for symbol in "\!blank"  "#0" "<s>" "</s>" "<space>" "<dummy>" ":" ";" "," "\."; do grep $symbol words_${page}.txt | awk '{print $2}' ; done | tr '\n' ' ')
      B=$(basename $b .gz);
      [ -e indx/$page/$B.gt ] && continue
      echo -n "Processing $B $page ..." 1>&2
      awk -v page=$page -v box=$B '
        BEGIN{ld="Line-Coords/"page"/"box".inf";
            while (getline < ld > 0) {
              W[$1]=$2; H[$1]=$3; 
            } 
            lc="Line-Coords/"page"/"box".crd";
            while (getline < lc > 0) {
              p=$1; $2=p"."$2; P[$2]=p; np[$2]=0; 
              mX[$2]=0; lX[$2]=W[p]-1; mY[$2]=0; lY[$2]=H[p]-1;
              for (i=3;i<=NF;i++) {
                split($i,A,",");
                if (A[1]<0) A[1]=0;
                if (A[1]>W[p]-1) A[1]=W[p]-1;
                if (A[2]<0) A[2]=0;
                if (A[2]>H[p]-1) A[2]=H[p]-1;
                np[$2]++; X[$2,np[$2]]=A[1]; Y[$2,np[$2]]=A[2];
                delete A;
                if (mX[$2]<X[$2,np[$2]]) mX[$2]=X[$2,np[$2]];
                if (lX[$2]>X[$2,np[$2]]) lX[$2]=X[$2,np[$2]];
                if (mY[$2]<Y[$2,np[$2]]) mY[$2]=Y[$2,np[$2]];
                if (lY[$2]>Y[$2,np[$2]]) lY[$2]=Y[$2,np[$2]]; 
              } 
            } 
          }{ 
            id=$1"."$2;
            printf P[id]" "id" "lX[id]" "mX[id]" "lY[id]" "mY[id]" "np[id]" ";
            for (i=1;i<=np[id];i++) printf X[id,i]" "Y[id,i]" "; print ""
            }' Line-Coords/$page/$B.crd > indx/$page/$B.gt

      echo "  Generating index ..." 1>&2

      lattice-char-index-position --print-args=false --verbose=2 --num-threads=4 --acoustic-scale=1 --insertion-penalty=0 --nbest=2500 "${separators}" "ark:gunzip -c LATs/$page/$B.gz |" ark,t:- 2>indx/$page/${B}.log |
      awk -v page=$page 'BEGIN{ file="words_"page".txt";
                while (getline < file > 0) M[$2]=$1
              }
              { 
                delete S; delete L; i=2;
                while (i<=NF-6) {
                  n=split($i,A,"_"); cad="";
                  for (j=1;j<=n;j++) cad=cad""M[A[j]];
                  cad=cad"_"$(i+1);
                  if (!(cad in S) || (S[cad]<exp($(i+4)))) {
                    S[cad]=exp($(i+4));
                    L[cad]=$1" "gensub(/_[0-9]+$/,"","g",cad)" "exp($(i+4))" "$(i+2)" "$(i+3)" "$(NF-1)" "$(i+1); 
                  }
                  i+=6;
                }
                for (cad in S) print L[cad]
              }' |
      gzip -9 -c > indx/$page/${B}.idx.gz
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 4 ]; then
  echo "##########################"
  echo "Get index density"
  echo "##########################"

  for page in "0" "1"; do
    for ind in indx/$page/*idx.gz; do
      density=$(zcat $ind | awk -v umb=0.0001 'BEGIN{expW=0.0;n=0;}{if ($3>umb) {n++;expW += $3;} }END{printf("%3.2f\n",n/expW)}')
      echo $ind" "$density
    done | tee logs/index_density_$page.log
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 5 ]; then
  echo "##########################"
  echo "Generating probabilistic index files for DEMO"
  echo "##########################"
  # Mapping word segmentation boundaries to corresponding page image coordinates
  # | awk '{split($1,a,"."); $1=a[1]"."a[3]; print $0}' |

  for page in "0" "1"; do
    for b in indx/$page/*.idx.gz; do
      B=$(basename $b .idx.gz);
      [ -d INDX/$page/$B ] || mkdir -p INDX/$page/$B

      echo "Processing $B $page ..." 1>&2
      cd INDX/$page/$B/
      ln -s ../../../IMAGES/$page/${B}/*.jpg ./
      cd -
      zcat $b | LC_ALL=C sort -k1V,2 -k4n,6n |
      awk 'BEGIN{
          pS=""; rpT=0;
        }
        {
          cS=$1"_"$2"_"$4"_"$5"_"$6;
          if (pS==cS) {
            rpT+=$3; pA=pA" "$7" "$3;
          } else {
            if (pS) print iw,rpT,sg,pA; pS=cS; rpT=$3;
            pA=$7" "$3; iw=$1" "$2; sg=$4" "$5" "$6;
          }
        }END{
            if (pS) print iw,rpT,sg,pA
        }' |
      awk -v gt="indx/$page/$B.gt" -v box="INDX/$page/$B" '
        BEGIN{
            print "Processing:",gt > "/dev/stderr";
            while (getline < gt > 0) {
              pg[$2]=$1; wdh[$2]=$4-$3+1; ofs[$2]=$3;
              ymx[$2]=$6; ymn[$2]=$5; npl[$2]=$7;
              for (p=1;p<=npl[$2];p++) {
                s=(p-1)*2+8; x[$2,p]=$(s); y[$2,p]=$(s+1)
              }
            }
          }
          {
            k=$1; if (!(k in pg)) next;
            scl=($6==0)?1:wdh[k]/$6;
            lb=int($4*scl+ofs[k]+.5);
            rb=int($5*scl+ofs[k]+.5);
            ymax=-100000; ymin=100000;
            for (p=1;p<=npl[k];p++) {
              x1=x[k,p]; y1=y[k,p];
              if (p==npl[k]) {
                x2=x[k,1]; y2=y[k,1];
              } else {
                x2=x[k,p+1]; y2=y[k,p+1];
              } 
              if ( ((x1<=lb && lb<=x2) || (x2<=lb && lb<=x1)) && (x2-x1)!=0 ) {
                m=(y2-y1)/(x2-x1); yaux=int(y1+m*(lb-x1)+.5);
                if (ymax<yaux) ymax=yaux;
                if (ymin>yaux) ymin=yaux;
              }
              if ( ((x1<=rb && rb<=x2) || (x2<=rb && rb<=x1)) && (x2-x1)!=0 ) {
                m=(y2-y1)/(x2-x1); yaux=int(y1+m*(rb-x1)+.5);
                if (ymax<yaux) ymax=yaux;
                if (ymin>yaux) ymin=yaux;
              }
              if (lb<=x1 && x1<=rb) {
                if (ymax<y1) ymax=y1;
                if (ymin>y1) ymin=y1;
              }
              if (lb<=x2 && x2<=rb) {
                if (ymax<y2) ymax=y2;
                if (ymin>y2) ymin=y2;
              }
            } 
            if (ymax==-100000) ymax=ymx[k];
            if (ymin==100000) ymin=ymn[k];
            pA="";
            for (i=7;i<=NF;i++) pA=pA" "$i;
            print $2,"0",$3,int((lb+rb)/2+.5),int((ymin+ymax)/2+.5),rb-lb+1,ymax-ymin+1,substr($1,length(pg[k])+2),pA >> box"/"pg[k]".idx"
          }' 2>INDX/$page/$B.log

      # Create dummy page PI for those pages which don't have corresponding IDX
      for f in INDX/$page/$B/*.jpg; do
        F=$(basename $f .jpg);
        [ -f ${f/\.jpg/.idx} ] || echo "-- 0 0.0 0 0 0 0 NA 0 0.0" > ${f/\.jpg/.idx}
      done
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 6 ]; then
  echo "##########################"
  echo "Replace the <decimal> symbol to a dot . and !print tag to uppercase"
  echo "##########################"

  sed -i 's/<decimal>/\./g' INDX/*/*/*idx
  sed -i "s|\!print|\!PRINT|g" INDX/*/*/*idx
  sed -i '/^\!/d' INDX/*/*/*idx

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi

if [ "$stage" -le 7 ]; then
  echo "##########################"
  echo "Creating thumbnails of the page images"
  echo "##########################"

  for page in "0" "1"; do
    for d in INDX/$page/*; do
      [ -d $d ] || continue;
      echo "Processing $d $page ...";
      mkdir $d/thumbs;
      for f in $d/*.jpg; do
        mogrify -format jpg -path $d/thumbs/ -thumbnail x120 -gravity center -crop 176x+0+0 $f
      done
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi

if [ "$stage" -le 8 ]; then
  echo "##########################"
  echo "Fix RP inconsistencies and prunning the index by RP<0.0001"
  echo "##########################"

  [ -d indx ] || mkdir -p indx
  cd indx;
  for page in "0" "1"; do
    cd $page
    for d in ../../INDX/$page/*; do
      [ -d $d ] || continue; D=$(basename $d);
      [ -d $D ] && continue; echo "Processing $d $page ..." 1>&2;
      mkdir $D; cd $D;
      ln -s ../$d/thumbs .;
      for f in ../$d/*.idx; do
        F=$(basename $f); cp -s ${f/\.idx/.jpg} .; cat $f |
        awk '{
            if ($4+$5+$6+$7!=0 && $3>0.0001) {
              if ($3>1) $3=1;
              if ($6<5) {
                if ($4-2>0) $6=5;
              } print $0
            } 
          }' > $F;
      done; cd ..;
    done; cd ..;
  done; cd ..;

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi

if [ "$stage" -le 9 ]; then
  echo "##########################"
  echo "Set the main image for DEMO"
  echo "##########################"

  [ -e HisClima ] || ln -fs indx/ HisClima
  cd HisClima
  ln -s 0/test/vol003_186_0.jpg HisClima_fp_0.jpg
  ln -s 1/test/vol003_186_1.jpg HisClima_fp_1.jpg
  cd -

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi


if [ "$stage" -le 10 ]; then
  echo "##########################"
  echo "Obtain the index statistics"
  echo "##########################"

  for page in "0" "1"; do
    for d in indx/$page/*; do
      [ -d $d ] || continue;
      echo -n "${d##*/} ";
      echo "$(grep -vEh -m1 "^--" $d/*.idx | wc -l) $(grep -vEh "^--" $d/*.idx | wc -l) $(awk '{s+=$3}END{print s}' $d/*.idx)" | awk '{print ($3!=0&&$1!=0)?$1" "$2" "$3" "$2/$1" "$2/$3:$1" "$2" "$3" - -"}';
    done |
    LC_ALL=C sort -rgk6,6 | column -t > stat_${page}.inf
    awk '{np+=$2; ns+=$3; nr+=$4}END{printf("%d %d %.0f %1.1f %.0f %.0f\n",np,ns,nr,ns/nr,ns/np,nr/np)}' stat_${page}.inf
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi

if [ "$stage" -le 11 ]; then
  echo "##########################"
  echo "Evaluate index"
  echo "##########################"
  # Require: kws-assessment
  # git clone https://github.com/PRHLT/KwsEvalTool.git

  [ -d results ] || mkdir results

  for page in "0" "1"; do
    for partition in "val" "test" "dla_test"; do
      # Obtaining GT
      cat ../HTR/data/text/transcriptions_${partition}_word_${page}.txt | sed "s|\!blank||g; s|\!print|\!PRINT|g; s|[;:,\.]\!PRINT||g; s|[;:,\.]||g; s|<decimal>|\.|g; s|\([0-9]\)t|\1\.t|g" > /tmp/GT_${partition}_${page}.txt
      # Obtaining the page PIs to evaluate
      cat ../HTR/data/lists/${partition}_${page}.lst | sed 's/\..*//' | sort -u |
      while read -a V; do
        find HisClima/${page}/${partition} -name "${V}.idx" -exec cat {} \; |
        awk -v pg=${V} '{print pg"."$8,$1,$3}';
      done |
      awk -v GT_file=/tmp/GT_${partition}_${page}.txt 'BEGIN{ while (getline < GT_file > 0) for (i=2;i<=NF;i++) GT[$1"|"$i]=0}{if ($1"|"$2 in GT) {gt=1; GT[$1"|"$2]=1;} else gt=0; print $1,$2,gt,$3}END{for (l in GT) if (GT[l]==0) { split(l,A,"|"); print A[1],A[2],"1 -1.0" } }' > /tmp/probIndex_${partition}_${page}.idx
    done

    for partition in "val" "test"; do
      # Generating the lists of keywords
      cat /tmp/GT_${partition}_${page}.txt | awk '{for (i=2;i<=NF;i++) if (length($i)>1) print $i}' | sort -u > /tmp/keywords_${partition}_${page}.lst
    done

    cp /tmp/keywords_test_${page}.lst /tmp/keywords_dla_test_${page}.lst
    cp ../HTR/data/text/transcriptions_test_word_${page}.txt ../HTR/data/text/transcriptions_dla_test_word_${page}.txt

    for partition in "val" "test" "dla_test"; do
      kws-assessment -a -m -t -s /tmp/probIndex_${partition}_${page}.idx -w /tmp/keywords_${partition}_${page}.lst -l $(wc -l /tmp/GT_${partition}_${page}.txt | awk '{print $1}') 2>&1 | tee results/${partition}_${page}.stats

      # For plotting R-P curve
      kws-assessment -t -s /tmp/probIndex_${partition}_${page}.idx -w /tmp/keywords_${partition}_${page}.lst -l $(wc -l /tmp/GT_${partition}_${page}.txt | awk '{print $1}') > results/plot-RP_PI_${partition}_${page}.dat

      # To plot the Recall-Precision curve: R-P.pdf
      cd results/
      gnuplot plot-R-P_${page}.gnp
      cd ..
    done
  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi
