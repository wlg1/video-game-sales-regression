### Adds keyword col used for querying Reddit posts
#Input: Video_Games_Sales_as_at_22_Dec_2016.csv
#Output: games_w_keywords.csv

import pandas as pd
import re
import pdb, traceback, sys

def main():
  sales = pd.read_csv("Video_Games_Sales_as_at_22_Dec_2016.csv")
  sales = sales[sales['Year_of_Release'] >= 2010 ]
  sales = sales[sales['NA_Sales'] > 0]
  sales['Platform'] = sales['Platform'].replace('XOne', 'Xbox One')
  sales['Platform'] = sales['Platform'].replace('X360', 'Xbox 360')
  sales['Platform'] = sales['Platform'].replace('WiiU', 'Wii U')
  sales['Platform'] = sales['Platform'].replace('PSV', 'Vita')
  sales['Platform'] = sales['Platform'].replace('PC', 'Windows')
  sales.reset_index(drop=True, inplace=True)
  new_sales = pd.DataFrame(columns=sales.columns)
  keywords = []

  more_keywords = pd.read_csv("added_keywords.csv")
  kws_vals = [f.split(',') for f in more_keywords.keywords.tolist()]
  more_kws_dict = dict(zip(more_keywords.game, kws_vals))
  
  number_words = ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
                  'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X']
  for g, game_name in enumerate(sales['Name']):
    game_keywords = [game_name]
    #split game title into before and after :
    if ':' in game_name:
      game_keywords += game_name.split(':')
      game_keywords = [kw[1:] if kw[0]==' ' else kw for kw in game_keywords]

    #get rid of suffix numbers for sequels
    splitted = game_name.split()
    if re.sub('[,:()/]', '', splitted[-1]) in number_words or re.sub('[,:()/]', '', splitted[-1]).isnumeric():
      game_keywords.append(' '.join(splitted[:-1]))
    
    for game_name_2 in more_kws_dict.keys():
      if game_name_2 in game_name:
        game_keywords += more_kws_dict[game_name_2]
    keywords.append(','.join( list(set(game_keywords))) ) 
    new_sales = new_sales.append(sales.iloc[[g]])

  new_sales['keywords'] = keywords
  f = open('games_w_keywords.csv', "w+")
  new_sales.to_csv('games_w_keywords.csv', index=False)

if __name__ == "__main__":
  try:
    main()
  except:
    type, value, tb = sys.exc_info()
    traceback.print_exc()
    pdb.post_mortem(tb)
