#!/bin/bash

# Request 1 day of runtime:
#SBATCH --time=24:00:00

#SBATCH --nodes=1
#SBATCH --tasks-per-node=8

# Specify a job name:
#SBATCH -J MyMPIJob

# Specify an output file
#SBATCH -o MyMPIJob-%j.out
#SBATCH -e MyMPIJob-%j.out

# Run a command

module load revbayes

################################################################################
#
# RevBayes Example: Bayesian inference of phylogeny using a Jukes-Cantor model
# 
# This file: Runs the full MCMC on a single gene under the Jukes-Cantor 
#            substitution model using an unconstrained, non-clock tree.
#
# authors: Sebastian Hoehna, Tracy A. Heath, Michael Landis and Brian R. Moore
#
################################################################################

#######################
# Reading in the Data #
#######################

###### This just defines a single model for all sites #######

### Read in sequence data for both genes

data <- readDiscreteCharacterData("DQA_Lepus_Bayes.nex")

# Get some useful variables from the data. We need these later on.
n_species <- data.ntaxa()
taxa <- data.names()
n_branches <- 2 * n_species - 3

# set my move index
mi = 0



######################
# Substitution Model #
######################

kappa ~ dnLognormal(0,1)
moves[++mi] = mvScale(kappa, weight=1)
Q := fnK80(kappa)

#############################
# Among Site Rate Variation #
#############################

alpha_prior<- 0.5
alpha ~ dnExponential( alpha_prior )
gamma_rates := fnDiscretizeGamma( alpha, alpha, 4, false )

# add moves the shape parameter
moves[++mi] = mvScale(alpha,weight=2)


##############
# Tree model #
##############

# construct a variable for the tree drawn from a birth death process
topology ~ dnUniformTopology(taxa)

# add topology Metropolis-Hastings moves
moves[++mi] = mvNNI(topology, weight=1.0)
moves[++mi] = mvSPR(topology, weight=1.0)

# create branch length vector and add moves
for (i in 1:n_branches) {
   br_lens[i] ~ dnExponential(10.0)
   moves[++mi] = mvScale(br_lens[i])
}

# add deterministic node to monitor tree length
TL := sum(br_lens)

# unite topology and branch length vector into phylogeny object
phylogeny := treeAssembly(topology, br_lens)



###################
# PhyloCTMC Model #
###################

# the sequence evolution model
seq ~ dnPhyloCTMC(tree=phylogeny, Q=Q, siteRates=gamma_rates, type="DNA")

# attach the data
seq.clamp(data)



#############
# THE Model #
#############

# We define our model.
# We can use any node of our model as a handle, here we chose to use the rate matrix.
mymodel = model(Q)


monitors[1] = mnModel(filename="output/DQA_Lepus_K80g2_posterior.log",printgen=10, separator = TAB)
monitors[2] = mnFile(filename="output/DQA_Lepus_K80g2_posterior.trees",printgen=10, separator = TAB, phylogeny)
monitors[3] = mnScreen(printgen=1000, TL)

mymcmc = mcmc(mymodel, monitors, moves, nruns=2)

mymcmc.burnin(generations=20000,tuningInterval=1000)
mymcmc.run(generations=1500000)


# Now, we will analyze the tree output.
# Let us start by reading in the tree trace
treetrace1 = readTreeTrace("output/DQA_Lepus_R1_posterior_run_1.trees", treetype="non-clock")
treetrace2 = readTreeTrace("output/DQA_Lepus_R1_posterior_run_2.trees", treetype="non-clock")
# and get the summary of the tree trace
#treetrace.summarize()

map_tree_1 = mapTree(treetrace1,"output/DQA_Lepus_R1_posterior_run_1.tree")
map_tree_2 = mapTree(treetrace2,"output/DQA_Lepus_R1_posterior_run_2.tree")

# you may want to quit RevBayes now
q()
