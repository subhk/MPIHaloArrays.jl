import MPI

const NNEIGHBORS_PER_DIM = 2     # Number of neighbors per dimension (left neighbor + right neighbor).
const NDIMS_MPI = 3              # Internally, we set the number of dimensions always to 3 for calls to MPI. This ensures a fixed size for MPI coords, neigbors, etc and in general a simple, easy to read code.

include("utils/indexing.jl")
include("sync_edges.jl")

function init_global_grid(nx::Integer, ny::Integer, nz::Integer; 
                          dimx::Integer=0, dimy::Integer=0, dimz::Integer=0, nhalo=2,
                          periodx::Integer=0, periody::Integer=0, periodz::Integer=0, 
                          disp::Integer=1, reorder::Integer=1, comm::MPI.Comm=MPI.COMM_WORLD, init_MPI::Bool=true, quiet::Bool=false)

    nxyz          = [nx, ny, nz];
    dims          = [dimx, dimy, dimz];
    periods       = [periodx, periody, periodz];

    dims[(nxyz .== 1) .& (dims .== 0)] .= 1;   # Setting any of nxyz to 1, means that the corresponding dimension must also be 1 in the global grid. Thus, the corresponding dims entry must be 1.
    
    if (init_MPI)  # NOTE: init MPI only, once the input arguments have been checked.
        if (MPI.Initialized()) error("MPI is already initialized. Set the argument 'init_MPI=false'."); end
        MPI.Init();
    else
        if (!MPI.Initialized()) error("MPI has not been initialized beforehand. Remove the argument 'init_MPI=false'."); end  # Ensure that MPI is always initialized after init_global_grid().
    end

    nprocs    = MPI.Comm_size(comm);
    MPI.Dims_create!(nprocs, dims);
    comm_cart = MPI.Cart_create(comm, dims, periods, reorder);
    me        = MPI.Comm_rank(comm_cart);
    coords    = MPI.Cart_coords(comm_cart);
    neighbors = fill(MPI.MPI_PROC_NULL, NNEIGHBORS_PER_DIM, NDIMS_MPI);
    for i = 1:NDIMS_MPI
        neighbors[:,i] .= MPI.Cart_shift(comm_cart, i - 1, disp);
    end
    return me, neighbors, dims, nprocs, coords, comm_cart # The typical use case requires only these variables; the remaining can be obtained calling get_global_grid() if needed.
end

# function print_arr(U)
#     for proc in 0:nprocs
#         if me == proc
#             println()
#             println("proc: ", proc)
#             for j in size(U, 2):-1:1
#                 println("j ", j, ":\t", U[:,j])
#             end
#         end
#         MPI.Barrier(comm_cart)
#     end
# end

# ni = 8
# nj = 10
# nhalo = 2
# me, neighbors, dims, nprocs, coords, comm_cart = init_global_grid(ni, nj, 1)

# ilo_neighbor, jlo_neighbor, klo_neighbor = neighbors[1,:]
# ihi_neighbor, jhi_neighbor, khi_neighbor = neighbors[2,:]

# U = zeros(ni, nj)
# U .= me

# print_arr(U)

# println("After")
# print_arr(U)

# MPI.Finalize()
