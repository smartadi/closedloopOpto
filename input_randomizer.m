function [amp dur rest] =  inp_randomizer()


max_amp = 3
min_amp = 0.5
max_dur = 2
min_dur = 0.1

amp = min_amp + (max_amp-min_amp*rand());
dur = min_dur + (max_dur-min_dur*rand());
rest = 9*dur

