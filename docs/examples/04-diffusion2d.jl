using MPI, MPIHaloArrays
using Plots
gr()

MPI.Init()
const comm = MPI.COMM_WORLD
const rank = MPI.Comm_rank(comm)
const nprocs = MPI.Comm_size(comm)

"""Establish the initial conditions, e.g. place a high temp rectangle in the center"""
function initialize!(x, y, T_0, T_c)
    T = zeros(length(x), length(y))
    fill!(T, T_0)

    dx0 = 0.2 # size of the central region
    dy0 = 0.3 # size of the central region
    for j in 1:length(y)
        for i in 1:length(x)
            if -dx0 < x[i] < dx0 && -dy0 < y[j] < dy0
                T[i, j] = T_c
            end
        end
    end
    return T
end

"""Perform 2D heat diffusion"""
function diffusion!(T, T_new, α, dt, dx, dy)
    ilo, ihi, jlo, jhi = localindices(T)
    for j in jlo:jhi
        for i in ilo:ihi
            T_new[i, j] = T[i, j] + α * dt * ((T[i-1, j] - 2 * T[i, j] + T[i+1, j]) / dx^2 +
                                              (T[i, j-1] - 2 * T[i, j] + T[i, j+1]) / dy^2)
        end
    end
end

function plot_temp(T, iter; root = 0)
    T_result = gatherglobal(T; root = root)
    if rank == root
        println("Plotting t$(iter).png")
        p1 = contour(T_result, fill = true, color = :viridis, aspect_ratio = :equal)
        plot(p1)
        savefig("t$(iter).png")
    end
end

root = 0 # root rank
dx = 0.01;
dy = 0.01; # grid spacing
α = 0.1 # thermal diffusivity
dt = dx^2 * dy^2 / (2.0 * α * (dx^2 + dy^2)) # stable time step

x = -1:dx:1 |> collect # x grid 
y = -2:dy:2 |> collect # y grid 

T_0 = 100.0 # initial temperature
T_c = 200.0 # temperature at the center hot region

# Initialize the temperature field
T_global = initialize!(x, y, T_0, T_c)

if rank == root
    println("Plotting initial conditions")
    p1 = contour(T_global, fill = true, color = :viridis, aspect_ratio = :equal)
    plot(p1)
    savefig("t0.png")
end

@assert nprocs == 4 "This example is designed with 4 processes, but can be changed in the topology construction..."
topology = CartesianTopology(comm, [2, 2], [true, true]) # periodic boundary conditions

nhalo = 1
Tⁿ = scatterglobal(T_global, root, nhalo, topology; do_corners = false)
Tⁿ⁺¹ = deepcopy(Tⁿ)
updatehalo!(Tⁿ)

plot_temp(Tⁿ, 0)

niter = 500
plot_interval = 50

ilo, ihi, jlo, jhi = localindices(Tⁿ)

for iter in 1:niter
    if rank == root
        println("Iteration: $iter")
    end

    updatehalo!(Tⁿ)
    diffusion!(Tⁿ, Tⁿ⁺¹, α, dt, dx, dy)
    Tⁿ.data .= Tⁿ⁺¹.data # update the next time-step

    if iter % plot_interval == 0
        plot_temp(Tⁿ, iter)
    end
end

GC.gc()
MPI.Finalize()