% Author: Abhiroop Paul
% Date: 31st July 2026
%
% TITLE: Hybrid Model of Bridged FD and KS Sympathetic String
% 
% DESCRIPTION:
% A stylised reverb in which only selected notes resonate, similar to the
% effect of sympathetic strings heard in many Asian string instruments such
% as the sitar. A bank of Karplus-Strong resonators excited continually by
% the input audio are used to simulate the sympathetic string effect.
% 
% The file name of the input audio file must be specified in the top section.
% The tuning configuration of the sympathetic strings is specified in a vector.
%
% The output can be convolved with a IR of a sitar's body. This can be used
% to simulate the full sound of a sitar when applied on an isolated sitar
% string recording or simulation. The user must input the midi value of the
% note they desire to generate (for example 60 for the note C4).
%
% DEPENDENCIES:
% The user must ensure the following files are in the folder path for the
% scheme to work:
%
% AP_midi2f.m
% AP_myfastconv.m
% AP_fadeOut.m
% IR_Contact_1.wav / IR_Condenser_1.wav
%
% =======================================================================
clear all; close all; clc;

% ====================================
% GLOBAL INPUT PARAMETERS
% ====================================
% Audio Read
[x_in,Fs] = audioread("Guitar_dry.wav");

% Conversion of audio to mono if stereo audio
if size(x_in,2) == 2
    Fn = 0.5 * (x_in(:,1) + x_in(:,2));
else
    Fn = x_in;
end

% FADEOUT TIME
tFo =   0.025;

% SYMPATHETIC STRING PARAMETERS
% Sympathetic String Notes
midi_s  =   [50;55;57; 62;74; 61;62;57;64;65;67;57;69;70;73;74;76;77];
Ns      =   length(midi_s);

sig_s   =   0.99;                       % Sympathetic String Sustain Factor

% COUPLING FACTOR
g       =   1.5e-1;                       % Coupling Factor

% OUTPUT RELATED
listen  =   true;                       % Sound output yes or no?
wetness =   0.77;
bodyIR  =   1;                          % Body filter: 0: no conv., 1: contact mic IR, 2: cond. mic IR
write   =   false;                       % Turn on to write selected output to file


% ====================================
% GLOBAL CALCULATED PARAMETERS
% ====================================
M       =   length(x_in);               % Samples in full simulation

f_s      =   zeros(Ns,1);               % Fundamental frequencies vector
for l   =   1:Ns
    f_s(l)   =   AP_midi2f(midi_s(l));
end

N_symp  =   floor((Fs ./ f_s) - 0.5);           % Sympathetic strings delay line lengths

Nfrac_s =   ((Fs ./ f_s) - 0.5) - N_symp;       % Fractional delay: sympathetic string

C_symp  =   (1-Nfrac_s)./(1+Nfrac_s);           % Allpass coefficient: sympathetic string


% ====================================
% CREATE VECTORS
% ====================================
y_s     =   zeros(M,Ns);

out_s   =   zeros(M,1);

w       =   zeros(1,Ns);                % Temporary states before allpass
w1      =   zeros(1,Ns);                % Previous temporary states

% Timer start for runtime
tic
% ====================================
% MAIN KS LOOP
% ====================================

for n   =   1:M
    for m   =   1:Ns
        % SYMPATHETIC STRING LOOP
        if n < N_symp(m) + 1
            y_s(n,m)    =   g * Fn(n);
        elseif n == N_symp(m) + 1
            y_s(n,m)    =   g * sqrt(sig_s)/2 * Fn(1);
        elseif n > N_symp(m) + 1
            w(m)      =   ( sqrt(sig_s)/2 * ( y_s(n-N_symp(m),m) + y_s(n-N_symp(m)-1,m) ) )   +   g * Fn(n);
            y_s(n,m)    =   (C_symp(m)*w(m)) + w1(m) - C_symp(m)*y_s((n - 1),m); 
        end
    end

    % Update previous states
    w1 = w;

end

% ====================================
% SUMMING, NORMALISATION & OUTPUT
% ====================================
out_m       =   Fn;                   % Main string output

% SUMMING ALL SYMPATHETIC STRINGS
for l   =   1:length(f_s)
    out_s       =   out_s + (y_s(:,l) / Ns);
end

% REMOVE DC OFFSET
out_m   = out_m - mean(out_m);
out_s   = out_s - mean(out_s);

% SUMMING MAIN + SYMPATHETICS
out     =   ((1-wetness) * out_m) + (wetness * out_s);
out     = out - mean(out);          % DC removal from summed output              

% NORMALISATION
out   =   out / max(abs(out));

% CONVOLUTION WITH BODY IR
if floor(mod(bodyIR,3)) == 1
    hIR     =   audioread("IR_Contact_1.wav");
    body    =   "ContactIR";  
elseif floor(mod(bodyIR,3)) == 2
    hIR     =   audioread("IR_Condenser_1.wav");
    body    =   "CondIR";
else
    body    =   "NoBody";
    hIR     =   [1;zeros(length(out_m),1)];
end
out     =   AP_myfastconv(hIR,out);

% FADEOUT
out     =   AP_fadeOut(out,tFo,Fs);

% SOUND OUTPUT
if listen == true
    soundsc(out,Fs);
end

% Timer end for runtime
toc

% WRITE TO FILE
if write == true
    % Audiowrite
    
    audiowrite("KS_SympVerb_Output.wav",out,Fs);
end

% ==================================END===================================