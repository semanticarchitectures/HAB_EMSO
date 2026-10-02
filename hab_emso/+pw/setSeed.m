function setSeed(seed)
%PW.SETSEED Seed the global random generators (MATLAB and Octave).
if exist('OCTAVE_VERSION', 'builtin')
    rand('state', seed); randn('state', seed); %#ok<RAND>
else
    rng(seed, 'twister');
end
end
