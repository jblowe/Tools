t=$1
grep -h INFO ~/${t}/logs/logfile.txt* | grep -v csvdump | grep -v KeyError | grep -v SMBConnection | grep -v watermark | grep -v urllib3 | grep -v AuthN | grep -v accountperms | grep -v delete| perl -pe 's/\[(.*?) (.*?)\] (\w+) \[(.*?)\] (.*?) :: (.*?)(end| )::? (.*?)( :: .*?)?//${t}\t\1\t\2\t\3\t\4\t\5\t\6\t\7\t\8/'  > ${t}.temp1
grep -h DEBUG ~/${t}/logs/logfile.txt* | grep -v KeyError | grep -v SMBConnection | grep -v watermarking |grep -v urllib3 | grep -v 'could not authenticate' | perl -pe 's/\[(.*?) (.*?)\] (\w+) \[(.*?)\] User: (.*) authenticated with Host: (.*)/${t}\t\1\t\2\t\3\t\4\t\5\t\6/' >> ${t}.temp1
cat ${t}.temp1 ${t}.django.log | perl -ne 'print unless /text:\(\+(rotogravure|Monterey|prominent|preserve|glazed)\)/' | sort -u > ${t}.temp2
mv ${t}.temp2 ${t}.django.log
rm ${t}.temp*
cut -f5 ${t}.django.log | perl -pe 's/:\d+//;s/\.(views|authn|utils|grouputils|eloan)//' | sort |uniq -c | sort -rn | head -20 > ${t}.logsummary.txt &
echo "	${t}" > ${t}.temp.txt
echo -e "aafirst log date\t`cut -f2 ${t}.django.log | sort -u | perl -pe 's/\// /g' | sort -k3 -k2M -k1 | head -1`" >> ${t}.temp.txt
echo -e "aalast log date\t`cut -f2 ${t}.django.log | sort -u | perl -pe 's/\// /g' | sort -k3 -k2M -k1 | tail -1`" >> ${t}.temp.txt
echo -e "aandays of activity\t`cut -f2 ${t}.django.log | sort -u | perl -pe 's/\// /g' | sort -k3 -k2M -k1 | wc -l`" >> ${t}.temp.txt
wait
perl -ne 's/^ *(\d+) (.*)$/\2\t\1/;print unless (length > 25)' ${t}.logsummary.txt | sort >> ${t}.temp.txt
