import random                                                                                                                              


for i in range(1000):
   with open("rand/{}".format(i), 'w') as f:
     f.write("".join([str(random.normalvariate(0, 1)) + "," for _ in range(64*100)]))
