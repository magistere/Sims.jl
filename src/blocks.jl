
########################################
## Continuous Blocks
########################################


function Integrator(u::Signal, y::Signal, k::Real)
    {
     der(y) - k .* u
     }
end


function Derivative(u::Signal, y::Signal, k::Real, T::Real)
    x = Unknown()  # state of the block
    zeroGain = abs(k) < eps()
    {
     der(x) - (zeroGain ? 0 : (u - x) ./ T)
     y - (zeroGain ? 0 : (k ./ T) .* (u - x))
     }
end


function LimPID(u_s::Signal, u_m::Signal, y::Signal,
                controllerType::String,
                k::Real, Ti::Real, Td::Real, yMax::Real, yMin::Real, wp::Real, wd::Real, Ni::Real, Nd::Real)
    with_I = any(controllerType .== ["PI", "PID"])
    with_D = any(controllerType .== ["PD", "PID"])
    x = Unknown()  # node just in front of the limiter
    d = Unknown()  # input of derivative block
    D = Unknown()  # output of derivative block
    i = Unknown()  # input of integrator block
    I = Unknown()  # output of integrator block
    zeroGain = abs(k) < eps()
    {
     u_s - u_m + (y - x) / (k * Ni) - i
     with_I ? Integrator(i, I, 1/Ti) : {}
     with_D ? Derivative(d, D, Td, max(Td/Nd, 1e-14)) : {}
     u_s - u_m - d
     Limiter(x, y, yMax, yMin)
     x - k * ((with_I ? I : 0.0) + (with_D ? D : 0.0) + u_s - u_m)
     }
end

function StateSpace(u::Signal, y::Signal,
                    A::Array{Real}, B::Array{Real}, C::Array{Real}, D::Array{Real})
    x = Unknown(zeros(size(A, 1)))  # state vector
    {
     A * x + B * u - der(x)
     C * x + D * u - y
     }
end

function TransferFunction(u::Signal, y::Signal,
                          b::Vector{Float64}, a::Vector{Float64})
    na = length(a)
    nb = length(b)
    nx = length(a) - 1
    bb = [zeros(max(0, na - nb)), b]
    d = bb[1] / a[1]
    a_end = (a[end] > 100 * eps() * sqrt(a' * a)[1]) ? a[end] : 1.0
    
    x = Unknown(zeros(nx))
    x_scaled = Unknown(zeros(nx))
    
    if nx == 0
        y - d * u
    else
       {
        der(x_scaled[1]) - (-a[2:na] .* x_scaled + a_end * u) / a[1]
        der(x_scaled[2:nx]) - x_scaled[1:nx-1]
        -y + ((bb[2:na] - d * a[2:na]) .* x_scaled) / a_end + d * u
        x - x_scaled / a_end
       }
    end
end




########################################
## Nonlinear Blocks
########################################



function Limiter(u::Signal, y::Signal, uMax::Real, uMin::Real)
    {
     y - ifelse(u > uMax, uMax,
                ifelse(u < uMin, uMin,
                       u))
     }
end

function Limiter(u::Signal, y::Signal, uMax::Real, uMin::Real)
    clamped_pos = Discrete(false)
    clamped_neg = Discrete(false)
    {
     BoolEvent(clamped_pos, u - uMax)
     BoolEvent(clamped_neg, uMin - u)
     y - ifelse(clamped_pos, uMax,
                ifelse(clamped_neg, uMin,
                       u))
     }
end

function DeadZone(u::Signal, y::Signal, uMax::Real, uMin::Real)
    pos = Discrete(false)
    neg = Discrete(false)
    {
     BoolEvent(pos, u - uMax)
     BoolEvent(neg, uMin - u)
     y - ifelse(pos, u - uMax,
                ifelse(neg, u - uMin,
                       0.0))
     }
end


