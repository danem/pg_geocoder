# Simplest possible ranking scheme
def extractLikeyRow (rows):
    return max(rows, key=lambda x: len(x.alternatenames))
