%TWIST SE(2) and SE(3) Twist class
%
% A Twist class holds the parameters of a twist, a representation of a
% rigid body displacement in SE(2) or SE(3).
%
% Methods::
%  s             twist vector (1x3 or 1x6)
%  S             twist as (augmented) skew-symmetric matrix (3x3 or 4x4)
%  T             convert to SE(2/3) homogeneous transformation
%  expm          synonym for T
%  pitch         pitch of the screw, SE(3) only
%  point         a point on the line of the screw
%  theta         rotation about the screw
%  line          Plucker line object representing line of the screw
%  display       print the Twist parameters in human readable form
%  char          convert to string
%
% Overloaded operators::
%  +             compose two Twists
%  *             multiply Twist by a scalar
%
% Properties (read only)::
%  v             moment part of twist (2x1 or 3x1)
%  w             direction part of twist (1x1 or 3x1)
%
% References::
% - "Mechanics, planning and control"
%   Park & Lynch, Cambridge, 2016.
%
% See also trexp, trexp2, trlog.

classdef Twist
    properties (SetAccess = protected)
        v
        w
    end
    
    methods
        function tw = Twist(T, varargin)
        %Twist.Twist Create Twist object
        %
        % TW = Twist(T) is a Twist object representing the SE(2) or SE(3)
        % homogeneous transformation matrix T (3x3 or 4x4).
        %
        % 3D CASE::
        %
        % TW = Twist('R', A, Q) is a Twist object representing rotation about the
        % axis of direction A (3x1) and passing through the point Q (3x1).
        %
        % TW = Twist('R', A, Q, P) as above but with a pitch of P (distance/angle).
        %
        % TW = Twist('T', A) is a Twist object representing translation in the
        % direction of A (3x1).
        %
        % 2D CASE::
        %
        % TW = Twist('R', Q) is a Twist object representing rotation about the point Q (2x1).
        %
        % TW = Twist('T', A) is a Twist object representing translation in the
        % direction of A (2x1).
        %
        % Notes::
        %  The argument 'P' for prismatic is synonymous with 'T'.

            if ischar(T)
                % 'P', dir
                % 'R', dir, point 3D
                % 'R', point   2D
                switch upper(T)
                    case 'R'
                        if nargin == 2
                            % 2D case
                            
                            point = varargin{1};
                            v = -cross([0 0 1]', [point(:); 0]);
                            w = 1;
                            v = v(1:2);
                        else
                            % 3D case
                            dir = varargin{1};
                            if length(dir) < 3
                                error('RTB:Twist:badarg', 'For 2d case can only specify position');
                            end
                            point = varargin{2};
                            
                            w = unit(dir(:));
                            
                            v = -cross(w, point(:));
                            if nargin >= 4
                                pitch = varargin{3};
                                v = v + pitch * w;
                            end
                        end
                        
                    case {'P', 'T'}
                        dir = varargin{1};
                        
                        if length(dir) == 2
                            w = 0;
                        else
                            w = [0 0 0]';
                        end
                        v = unit(dir(:));
                end
                
                tw.v = v;
                tw.w = w;
            elseif numrows(T) == numcols(T)
                % it's a square matrix
                if T(end,end) == 1
                    % its a homogeneous matrix, take the logarithm
                    if numcols(T) == 4
                        S = trlog(T);  % use closed form for SE(3)
                    else
                        S = logm(T);
                    end
                    [skw,v] = tr2rt(S);
                    tw.v = v;
                    tw.w = vex(skw);
                else
                    % it's an augmented skew matrix, unpack it
                    [skw,v] = tr2rt(T);
                    tw.v = v;
                    tw.w = vex(skw)';
                end
            elseif numrows(T) == 1
                % its a row vector form of twist, unpack it
                switch length(T)
                    case 3
                        tw.v = T(1:2)'; tw.w = T(3);
                        
                    case 6
                        tw.v = T(1:3)'; tw.w = T(4:6)';
                        
                    otherwise
                        error('RTB:Twist:badarg', '3 or 6 element vector expected');
                end
            end
        end
        
        function x = s(tw)
        %Twist.s Return the twist vector
        %
        % TW.s is the twist vector in se(2) or se(3) as a vector (1x3 or 1x6).
        %
        % Notes::
        % - Sometimes referred to as the twist coordinate vector.
            x = [tw.v; tw.w]';
        end
        
        function x = S(tw)
        %Twist.S Return the twist matrix
        %
        % TW.S is the twist matrix in se(2) or se(3) which is an augmented
        % skew-symmetric matrix (3x3 or 4x4).
        %

            x = [skew(tw.w) tw.v(:)];
            x = [x; zeros(1, numcols(x))];
        end
        
        function c = plus(a, b)
        %Twist.plus Compose twists
        %
        % TW1 + TW2 is a new Twist representing the composition of twists TW1 and
        % TW2.
        %

            if isa(a, 'Twist') & isa(b, 'Twist')
                c = Twist(a.s + b.s);
            else
                error('RTB:Twist: incorrect operands for + operator')
            end
        end
        
        function c = mtimes(a, b)
        %Twist.mtimes Linear scaling of a twist
        %
        % A*TW is a Twist with its twist coordinates scaled by A.
        % TW*A as above.
        %

            if isa(a, 'Twist') & isreal(b)
                    c = Twist(a.s * b);
                elseif isreal(a) & isa(b, 'Twist')
                    c = Twist(a * b.s);
                else
                    error('RTB:Twist: incorrect operands for * operator')
                end
            end
        
        function x = expm(tw, varargin)
        %Twist.expm Convert twist to homogeneous transformation
        %
        % TW.expm is the homogeneous transformation equivalent to the twist (3x3 or 4x4).
        %
        % TW.expm(THETA) as above but with a rotation of THETA about the twist.
        %
        % Notes::
        % - For the second form the twist must, if rotational, have a unit rotational component.
        %
        % See also Twist.T, trexp, trexp2.
            if length(tw.v) == 2
                    x = trexp2( tw.S, varargin{:} );
                else
                    x = trexp( tw.S, varargin{:} );
                end
            end
        
        function x = T(tw, varargin)
        %Twist.T Convert twist to homogeneous transformation
        %
        % TW.T is the homogeneous transformation equivalent to the twist (3x3 or 4x4).
        %
        % TW.T(THETA) as above but with a rotation of THETA about the twist.
        %
        % Notes::
        % - For the second form the twist must, if rotational, have a unit rotational component.
        %
        % See also Twist.exp, trexp, trexp2.
            x = tw.expm( varargin{:} );
        end
        
        function p = pitch(tw)
        %Twist.pitch Pitch of the twist
        %
        % TW.pitch is the pitch of the Twist as a scalar in units of distance per radian.
        %
        % Notes::
        % - For 3D case only.
        
        if length(tw.v) == 2
                p = 0;
            else
                p = tw.w' * tw.v;
            end
        end
        
        function L = line(tw)
        %Twist.line Line of twist axis in Plucker form
        %
        % TW.line is a Plucker object representing the line of the twist axis.
        %
        % Notes::
        % - For 3D case only.
        %
        % See also Plucker.
        
                % V = -tw.v - tw.pitch * tw.w;
                L = Plucker('UV', tw.w, -tw.v - tw.pitch * tw.w);
        end
        
        function p = point(tw)
        %Twist.point Point on the twist axis
        %
        % TW.point is a point on the twist axis (2x1 or 3x1).
        %
        % Notes::
        % - For pure translation this point is at infinity.
        if length(tw.v) == 2
                v = [tw.v; 0];
                w = [0 0 tw.w]';
                p = cross(w, v) / tw.theta();
                p = p(1:2);
            else
                p = cross(tw.w, tw.v) / tw.theta();
            end
        end
        
        function th = theta(tw)
        %Twist.theta Twist rotation
        %
        % TW.theta is the rotation (1x1) about the twist axis in radians.
        %

        th = norm(tw.w);
        end
        
            
        function s = char(tw)
        %Twist.char Convert to string
        %
        % s = TW.char() is a string showing Twist parameters in a compact single line format.
        % If TW is a vector of Twist objects return a string with one line per Twist.
        %
        % See also Twist.display.
        s = '';
            for i=1:length(tw)
                
                ps = '( ';
                ps = [ ps, sprintf('%0.5g  ', tw(i).v) ];
                ps = [ ps(1:end-2), '; '];
                ps = [ ps, sprintf('%0.5g  ', tw(i).w) ];
                ps = [ ps(1:end-2), ' )'];
                if isempty(s)
                    s = ps;
                else
                    s = char(s, ps);
                end
            end
            

        end
        
        function display(tw)
            %Twist.display Display parameters
            %
            % L.display() displays the twist parameters in compact single line format.  If L is a
            % vector of Twist objects displays one line per element.
            %
            % Notes::
            % - This method is invoked implicitly at the command line when the result
            %   of an expression is a Twist object and the command has no trailing
            %   semicolon.
            %
            % See also Twist.char.
            loose = strcmp( get(0, 'FormatSpacing'), 'loose');
            if loose
                disp(' ');
            end
            disp([inputname(1), ' = '])
            disp( char(tw) );
        end % display()
        
    end
end