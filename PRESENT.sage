#PRESENT

load("genModelBC.sage")

def PRESENT_model(rMax,ANF_firstS, ANF_S,ANF_lastS):
	#Create the MILP model for PRESENT over rMax rounds --WITHOUT-- the initial division property
	#Using S as the inbox for all round except the last one, where lastS is used instead

	#Generate the inequalities for the first S-box
	divTable_firstS = SboxDivTrailTable(ANF_firstS)
	ineq_firstS = sboxReducedInequalities(divTable_firstS)

	#Generate the inequalities for the standard S-box
	divTable_S = SboxDivTrailTable(ANF_S)
	ineq_S = sboxReducedInequalities(divTable_S)

	#Generate the inequalities for the last S-box
	divTable_lastS = SboxDivTrailTable(ANF_lastS)
	ineq_lastS = sboxReducedInequalities(divTable_lastS)

	#Permutation layer 
	P = [(16*i)%63 for i in range(63)]
	P.append(63)

	#Create the model
	m = Model("Present")

	#Create the variables of each round
	x = [[m.addVar(vtype=GRB.BINARY, name="x_"+str(i)+"_"+str(j)) for j in range(64)] for i in range(rMax+1)]

	#Set the objective
	m.setObjective(quicksum([x[rMax][i] for i in range(64)]), GRB.MINIMIZE)
	m.update()

	#Add the round function constraint for the first round
	r = 0
	for t in range(16): #For each Sbox
		inputvar = [x[r][4*t+i] for i in range(4)]
		outputvar = [x[r+1][P[4*t+i]] for i in range(4)]
		addSboxConstr(m, ineq_firstS, inputvar, outputvar)

	#Add the round function constraint for all the middle rounds
	for r in range(1,rMax-1): #For each round except the last
		for t in range(16): #For each Sbox
			inputvar = [x[r][4*t+i] for i in range(4)]
			outputvar = [x[r+1][P[4*t+i]] for i in range(4)]
			addSboxConstr(m, ineq_S, inputvar, outputvar)

	#Add the round function constraint for the last round
	r = rMax-1
	for t in range(16): #For each Sbox
		inputvar = [x[r][4*t+i] for i in range(4)]
		outputvar = [x[r+1][P[4*t+i]] for i in range(4)]
		addSboxConstr(m, ineq_lastS, inputvar, outputvar)

	return (m,x)

def PRESENT_searchDistinguisher(rMax,ANF_firstS,ANF_S,ANF_lastS,init):
	#Search for a distinguisher over rMax rounds using initial division property init
	#Use the Sbox ANF lastS for the last round, and S otherwise

	(m,x) = PRESENT_model(rMax,ANF_firstS,ANF_S,ANF_lastS)

	#Now add the constrains for the initial division property
	for i in range(64):
		m.addConstr(x[0][i] == init[i])

	m.update()
	# m.printStats()
	# print ""
	m.Params.OutputFlag = 0
	return searchDistinguisher(m)

def PRESENT_searchAllInit(rMax,ANF_firstS,ANF_S,ANF_lastS):
	fullruntime = 0
	for i0 in range(64):
		init = [1 for _ in range(64)]
		init[i0] = 0
		print "Init div " + str(i0)
		(L,totalruntime) = PRESENT_searchDistinguisher(rMax,ANF_firstS,ANF_S,ANF_lastS,init)
		fullruntime += totalruntime
		if len(L) == 0:
			print "No balanced bits" + "(" + ("%.2f" % totalruntime) + "s," + ("%.2f" % fullruntime) + " total time)"
		else:
			print "!! " + str(len(L)) + " balanced bits : " + str(L) + "(" + ("%.2f" % totalruntime) + "s," + ("%.2f" % fullruntime) + " total time)"

def oldPRESENTDistinguisher9r():
	"""Old known distinguisher over 9 rounds of PRESENT"""

	S = [0xC,0x5,0x6,0xB,0x9,0x0,0xA,0xD,0x3,0xE,0xF,0x8,0x4,0x7,0x1,0x2]
	(P,ANFS) = SBOX_ANF(S)
	init = [0,0,0,0] + [1 for _ in range(60)]
	(K,r) = PRESENT_searchDistinguisher(9,ANFS,ANFS,ANFS,init)
	print ""
	print "Balanced bits : " 
	print K

def twkPRESENTDistinguisher7r():
	"""Check the distinguisher of 7 rounds of the variant of PRESENT"""

	#This Sbox is obtained from the original S-box S' of PRESENT, using S = B o S' o A with
	# A = [[1,1,0,0],[1,0,0,0],[0,0,1,0],[0,0,0,1]]
	# B = [[1,1,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]
	S = [12, 10, 5, 7, 9, 13, 0, 11, 2, 8, 15, 14, 4, 3, 6, 1]
	Lin = matrix(GF(2),[[1,1,0,0],[1,0,0,0],[0,0,1,0],[0,0,0,1]])
	#Lout is the identity
	(P,ANFS) = SBOX_ANF(S)
	ANFSin = composeLinIn(ANFS,Lin)
	
	#input transition on S-box 0, 1011 -> 1010,1101,0111
	init = [1 for _ in range(64)]
	init[1] = 0
	(K,r) = PRESENT_searchDistinguisher(7,ANFSin,ANFS,ANFS,init)
	print ""
	print "Balanced bits : " 
	print K

def extend_PRESENT():
	#Try to apply the extension technique to PRESENT using another Sbox
	# S = [12, 13, 11, 9, 6, 0, 5, 10, 3, 2, 8, 4, 15, 7, 14, 1] #twkPRESENT 3XOR
	S = [12, 10, 5, 7, 9, 13, 0, 11, 2, 8, 15, 14, 4, 3, 6, 1] #twkPRESENT 2 XOR
	nbrounds = 6

	(P,ANFS) = SBOX_ANF(S)
	hexSbox = "".join(hex(ss) for ss in S)


	#Go through the vectors in weight order 2 - 3 - 1
	weight2vectors = [(1,1,0,0),(1,0,1,0),(0,1,1,0),(1,0,0,1),(0,1,0,1),(0,0,1,1)]
	weight3vectors = [(0,1,1,1),(1,0,1,1),(1,1,0,1),(1,1,1,0)]
	weight1vectors = [(1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1)]
	V = weight2vectors + weight3vectors + weight1vectors


	#Permutation layer 
	P = [(16*i)%63 for i in range(63)]
	P.append(63)
	Pinv = [0 for i in range(64)]
	for i in range(64):
		Pinv[P[i]] = i

	f = open("int_inconsistency_twkPRESENT"+hexSbox+".txt","w")
	for isbox in range(16): #For each Sbox
		for v in V:
			(m,x) = PRESENT_model(nbrounds,ANFS,ANFS,ANFS)
			#Initialisation constraints
			#The model starts AFTER the permutation layer
			#We want the initial division property BEFORE the permutation layer to be a vector of weight 2
			#Reorder the init variables using Pinv
			xinv = [0 for i in range(64)]
			for i in range(64):
				xinv[Pinv[i]] = x[0][i]

			#Set the constraints for the isbox-th Sbox
			# The 4 variables are xinv[4*isbox], xinv[4*isbox+1], xinv[4*isbox+2], xinv[4*isbox+3]
			xvar = [xinv[4*isbox+i] for i in range(4)]
			for i in range(4):
				m.addConstr(xvar[i] == v[i])

			#Set the constraints for the other Sboxes
			for i in range(4*isbox):
				m.addConstr(xinv[i] == 1)
			for i in range(4*isbox+4, 64):
				m.addConstr(xinv[i] == 1)

			#Additional constraint
			#Only search for vectors activating only one Sbox
			a = [m.addVar(vtype=GRB.BINARY, name="a"+str(i)) for i in range(16)]
			for i in range(16):
				m.addGenConstrMax(a[i], [x[nbrounds][4*i+j] for j in range(4)])
			m.addConstr(quicksum(a) == 1)
			m.update()
			print "Sbox " + str(isbox) + ", init " + str(v)
			m.write("./models/twkPRESENT/twkPRESENT_"+hexSbox+"_" + str(nbrounds) + "r_Sbox"+str(isbox)+"_"+"".join(str(c) for c in v)+".mps")
			(K,r) = computeFullDivisionProperty(m)
			print ""
			if len(K) > 1:
				if K[-1] == -1:
					del K[-1]
					f.write("Sbox " + str(isbox) + ", init " + str(v) + "\n")
			save(K,"./tweakedPRESENT/divSet_twkPRESENT_"+hexSbox+"_"+ str(nbrounds) + "r_Sbox"+str(isbox)+"_"+"".join(str(c) for c in v))