function build_redfield(iset::InteractionSet, U, tf; atol = 1e-8, rtol = 1e-6)
    if length(iset) == 1
        build_redfield(iset[1], U, tf, atol = atol, rtol = rtol)
    else
        RedfieldSet([
            build_redfield(i, U, tf, atol = atol, rtol = rtol)
            for i in iset.interactions
        ]...)
    end
end

build_redfield(i::Interaction, U, tf; atol = 1e-8, rtol = 1e-6) =
    build_redfield(i.coupling, U, tf, i.bath, atol = atol, rtol = rtol)

function build_CGME(
    iset::InteractionSet,
    U,
    tf;
    atol = 1e-8,
    rtol = 1e-6,
    Ta = nothing,
)
    if length(iset) == 1
        build_CGME(iset[1], U, tf, atol = atol, rtol = rtol, Ta = Ta)
    else
        throw(ArgumentError("InteractionSet is not supported for CGME for now."))
    end
end

build_CGME(i::Interaction, U, tf; atol = 1e-8, rtol = 1e-6, Ta = nothing) =
    build_CGME(i.coupling, U, tf, i.bath, atol = atol, rtol = rtol, Ta = Ta)

function build_davies(iset::InteractionSet, ω_range, lambshift::Bool)
    if length(iset) == 1
        build_davies(iset[1], ω_range, lambshift)
    else
        throw(ArgumentError("Multiple interactions is not yet supported for adiabatic master equation solver."))
    end
end

build_davies(inter::Interaction, ω_hint, lambshift) =
    build_davies(inter.coupling, inter.bath, ω_hint, lambshift)

function build_ss_control_from_interactions(
    i::Interaction,
    tf,
    field::Union{Nothing,Symbol},
)
    control = FluctuatorControl(tf, length(i.coupling), i.bath, field)
    opensys = StochasticNoise(i.coupling, field)
    control, opensys
end

function build_ss_control_from_interactions(
    iset::InteractionSet,
    tf,
    field::Union{Nothing,Symbol},
)
    if length(iset) == 1
        build_ss_control_from_interactions(iset[1], tf, field)
    else
        throw(ArgumentError("Multiple interactions is not yet supported for stochastic Schrodinger equation solver."))
    end
end

function build_ame_trajectory_control_from_interactions(
    inter::InteractionSet,
    ω_hint,
    lambshift,
    lvl,
    tf,
    H,
    ame_trajectory_de_field,
    fluctuator_de_field,
)
    a_control = []
    f_control = []
    opensys = nothing
    for i in inter.interactions
        if typeof(i.bath) <: EnsembleFluctuator
            c = FluctuatorControl(
                tf,
                length(i.coupling),
                i.bath,
                fluctuator_de_field,
            )
            push!(f_control, c)
            opensys = StochasticNoise(i.coupling, fluctuator_de_field)
        else
            d = build_davies(i, ω_hint, lambshift)
            op = AMETrajectoryOperator(H, d, lvl)
            push!(a_control, AMETrajectoryControl(op, ame_trajectory_de_field))
        end
    end
    if length(f_control) > 1
        error("Only single fluctuator ensemble is supported.")
    end
    if length(a_control) > 1
        error("Multi-axis bath is not yet supported.")
    end
    ControlSet(a_control..., f_control...), opensys
end

function build_hybrid_redfield_control_from_interactions(
    inter::InteractionSet,
    unitary,
    tf,
    atol,
    rtol,
    fluctuator_de_field,
)
    f_control = []
    f_opensys = []
    r_opensys = []
    for i in inter.interactions
        if typeof(i.bath) <: EnsembleFluctuator
            c = FluctuatorControl(
                tf,
                length(i.coupling),
                i.bath,
                fluctuator_de_field,
            )
            push!(f_control, c)
            push!(f_opensys, StochasticNoise(i.coupling, fluctuator_de_field))
        else
            s = build_redfield(
                i.coupling,
                unitary,
                tf,
                i.bath,
                atol = atol,
                rtol = rtol,
            )
            push!(r_opensys, s)
        end
    end
    if isempty(f_control)
        error("No fluctuator ensemble detected. Use solve_redfield instead.")
    elseif length(f_control) > 1
        error("Only single fluctuator ensemble is supported.")
    end

    if length(r_opensys) == 1
        r_opensys = r_opensys[1]
    else
        r_opensys = RedfieldSet(r_opensys...)
    end
    # currently only sinlge fluctuator ensemble is supported
    f_control[1], f_opensys[1], r_opensys
end
