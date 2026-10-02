function addPortPair(src, dst, name)
%ADDPORTPAIR Add an output port on src, an input port on dst, and connect.
%   System Composer API: addPort(<arch>, name, direction); getPort(comp, name);
%   connect(srcPort, dstPort)
addPort(src.Architecture, name, 'out');
addPort(dst.Architecture, name, 'in');
connect(getPort(src, name), getPort(dst, name));
end
