#!/bin/bash
for f in *.mp4;
	do size=$(du -k "$f" | cut -f1)
	if [ "$size" -ge 16001 ]; then
       		ffmpeg -i "$f" -c:v libx264 -crf 26 -profile:v baseline -level 3.0 -pix_fmt yuv420p "t-$f";
		sizeafter=$(du -k "t-$f" | cut -f1);
		sizefinal=$(($size-$sizeafter));
		echo "$f Inicio $size, Final $sizeafter com redução de $sizefinal bytes" >> changed.txt;
		mv "t-$f" "$f"
	fi 
done
cat changed.txt
rm changed.txt