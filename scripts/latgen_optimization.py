#!/bin/python

import numpy as np
from scipy.optimize import minimize
import subprocess
import os
import sys

utils="./utils/"

def function(x):
  """ order=ngram, x[0] = asf, x[1] = beam """

  LM=f"LM/{page}/{order}/LM"
  decode_process = subprocess.Popen(["decode-faster-mapped",
                                     "--verbose=2",
                                     "--allow-partial=true",
                                     f"--acoustic-scale={x[0]}",
                                     f"--beam={x[1]}",
                                     f"{LM}/new.mdl",
                                     f"{LM}/HCLG.fst",
                                     f"ark:{work_folder}/results/val_matrix.ark",
                                     f"ark,t:| {utils}/int2sym.pl -f 2- {LM}/words.txt > /tmp/decode_{order}_{x[0]}_{x[1]}_{page}.hyp",
                                     f"ark,t:/tmp/decode_{order}_{x[0]}_{x[1]}_{page}.ali"
                                     ])
  decode_process.wait()
  out, err = decode_process.communicate()

  evaluation_process = subprocess.Popen(["compute-wer",
                                         "--print-args=false",
                                         "--mode=present",
                                         f"ark:/tmp/decode_{order}_{x[0]}_{x[1]}_{page}.hyp",
                                         f"ark:data/text/transcriptions_val_char_{page}.txt"
                                         ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  evaluation_process.wait()
  out, err = evaluation_process.communicate()
  cer = str(out).split(" ")[1]
  print(f"{order}, {x[0]}, {x[1]}: {cer}")
  return float(cer)


if __name__ == "__main__":
  page = int(sys.argv[1])
  work_folder=f"work_{page}"
  for order in range(3, 15):
    fname=f"{work_folder}/decode/{order}/decode_val_optimization.results"
    print(fname)
    if (os.path.isfile(fname)):
      print("Done!")
    else:
      print("To do!")
      x0 = np.array([2.5, 25])
      res = minimize(function, x0, method='nelder-mead', options={'xatol': 1e-8, 'disp': True})

      print(res)
      if not os.path.exists(f"{work_folder}/decode/{order}"):
        os.makedirs(f"{work_folder}/decode/{order}")
      f = open(fname, "w")
      f.write(str(res))
      f.close()
  
