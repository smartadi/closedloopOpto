
[amp dur rest] = input_randomizer()

dt = 0.001; 
t1 = 0:dt:dur
t2 = dur:dt:(dur+rest)
a = amp/2+amp/2*sin(-pi/2+2*pi*40*t1)
b = 0*t2

signal = [a,b];
t=[t1,t2];

figure()
plot(t,signal);