
# arguments for the `train` function 
Base.@kwdef mutable struct MyArgs
    η = 0.001             # learning rate
    batchsize = 256      # batch size (number of graphs in each batch)
    epochs = 30         # number of epochs
    seed = 42             # set seed > 0 for reproducibility
    usecuda = true      # if true use cuda (if available)
    nin = 5
    ein = 4
    d1 = 128        # dimension of hidden features
    d2 = 128        # dimension of hidden features
    dout = 64        # dimension of hidden features
    infotime = 1      # report every `infotime` epochs
    numtrain = (0.5, 0.1)
    heads = 4
    dist = "norm"
end

struct GNN                                # step 1
    conv1
    bn1
    conv2
    bn2
    conv3
    bn3
    pool
    dense1
    bn3
    dense2
end

Flux.@functor GNN    

function GNN(nin::Int = 5, ein::Int = 4, d1::Int = 128, d2::Int = 64, dout::Int = 32, heads::Int = 4)
    GNN(
        GATv2Conv((nin, ein) => d1, add_self_loops = false, heads = heads),
        BatchNorm(d1 * heads),
        GATv2Conv((d1 * heads, ein) => d2, add_self_loops = false, heads = heads),
        BatchNorm(d2 * heads),
        GATv2Conv((d1 * heads, ein) => d2, add_self_loops = false, heads = heads),
        BatchNorm(d2 * heads),
        GlobalPool(mean),
        Dense(d2 * heads, dout),
        BatchNorm(dout),
        Dense(dout, dout),
    )
end

function GNN(args::MyArgs)
    GNN(args.nin, args.ein, args.d1, args.d2, args.dout, args.heads)
end

function (model::GNN)(g::GNNGraph, x, e)     # step 4
    x = model.conv1(g, x, e)
    x = model.bn1(x)
    x = leakyrelu.(x)
    x = model.conv2(g, x, e)
    x = model.bn2(x)
    x = leakyrelu.(x)
    x = model.conv3(g, x, e)
    x = model.bn3(x)
    x = leakyrelu.(x)
    x = model.pool(g, x)
    x = model.dense1(x)
    x = model.bn3(x)
    x = leakyrelu.(x)
    x = model.dense2(x)
    # x = model.bn4(x)
    return x 
end

function (model::GNN)(g::GNNGraph)
    model(g, g.ndata.x, g.edata.e)
end

function my_eval_loss_accuracy(model, data_loader, device, args)
    loss = 0.0
    ntot = 0
    for ((g1, g2), y) in ProgressBar(data_loader)
        g1, g2, y = (g1, g2, y) |> device
        emb1 = model(g1) |> vec
        emb2 = model(g2) |> vec
	emb1 = reshape(emb1, args.dout, length(y))
	emb2 = reshape(emb2, args.dout, length(y))
	ŷ = pairwise_l2_norm(emb1, emb2)
        #ŷ = norm(emb1 - emb2)
        #l = Flux.mse(ŷ, y)
	#l = sum(Flux.mse(ŷ[i], y[i]) for i in 1:length(y))
	l = mean((ŷ .- y).^2)
	loss += l
	# println("g1: ", g1.num_nodes, "g2: ", g2.num_nodes, "losses: ", l, "targets: ", y)
        ntot += length(y)
    end
    return (loss = round(loss / ntot, digits = 4))
end

function pairwise_l2_norm(A::AbstractArray, B::AbstractArray)
    if size(A) != size(B)
        error("The matrices are not the same size.")
    end

    return sqrt.(sum((A .- B).^2, dims=1))
end


function mytrainloop!(
    args::MyArgs, train_loader::DataLoader, test_loader::DataLoader, model::Union{GNNChain, GNN},
    opt::ADAM, device::Function, ps::Zygote.Params
)
    function report(epoch, trainloss = nothing, testloss = nothing)
        if trainloss === nothing
            trainloss = my_eval_loss_accuracy(model, train_loader, device, args)
        end
        if testloss === nothing
            testloss = my_eval_loss_accuracy(model, test_loader, device, args)
        end
        println("Epoch: $epoch   Train: $(trainloss)   Test: $(testloss)")
    end
    report(0)
    local training_loss
    for epoch in 1:(args.epochs)
        loss = 0.0
        ntot = 0
        for ((g1, g2), y) in ProgressBar(train_loader)
            g1, g2, y = (g1, g2, y) |> device
            gs = Flux.gradient(ps) do
                emb1 = model(g1) |> vec
                emb2 = model(g2) |> vec
		emb1 = reshape(emb1, args.dout, length(y))
		emb2 = reshape(emb2, args.dout, length(y))
		ŷ = pairwise_l2_norm(emb1, emb2)
		#ŷ = norm(emb1 - emb2)
                #training_loss = Flux.mse(ŷ, y)
		#training_loss = sum(Flux.mse(ŷ[i], y[i]) for i in 1:length(y))
		training_loss = mean((ŷ .- y).^2)
            end
            loss += training_loss
            ntot += length(y)
            Flux.Optimise.update!(opt, ps, gs)
        end
        epoch % args.infotime == 0 && report(epoch, round(loss / ntot, digits = 4))
    end
    model
end

function mytrain(dataset::Vector{GEDTrainPair}, model::Union{GNNChain, GNN, Nothing} = nothing; kws...)
    args = MyArgs(; kws...)
    args.seed > 0 && Random.seed!(args.seed)

    if args.usecuda && CUDA.functional()
        device = gpu
        args.seed > 0 && CUDA.seed!(args.seed)
        @info "Training on GPU"
    else
        device = cpu
        @info "Training on CPU"
    end
    if model === nothing
        model = GNN(args) |> device
    end

    # LOAD DATA
    graphs = [(pair.g1, pair.g2) for pair in dataset]
    dists = [pair.dists[args.dist] for pair in dataset]
    dataset = collect(zip(graphs, dists))
    train_data, test_data = splitobs(dataset, at = args.numtrain, shuffle = true)

    train_loader = DataLoader(train_data; args.batchsize, shuffle = true, collate = true)
    test_loader = DataLoader(test_data; args.batchsize, shuffle = false, collate = true)


    ps = Flux.params(model)
    opt = Adam(args.η)
    mytrainloop!(args, train_loader, test_loader, model, opt, device, ps)
end


