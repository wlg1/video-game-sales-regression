### Undos combine_games after scrapping Reddit posts
### Splits games on mulitple platforms into multiple rows, one platform per row
#Input: game_mentions_data_months.csv, games_w_rldates.csv
#Outputs: game_mentions_platform_split.csv

import pandas as pd
import pdb, traceback, sys

"""
open original file to get split platforms. loop through newer file and for each game, get all
duplicates and put them each back into the output file, copying the original row but adding
release month, and reddit data to the output.

Do this after scraping reddit bc saves time scrapping redundant games + release dates
"""
def main():
  orig = pd.read_csv("games_w_rldates.csv")
  sales = pd.read_csv("game_mentions_data_months.csv")
  new_sales = pd.DataFrame(columns=sales.columns)
  for index, row in sales.iterrows():
    dups = orig[(orig['Name'] == row['Name']) & (orig['release date'] == row['release date']) ]
    if len(dups) > 1:
      for index_d, row_d in dups.iterrows():
        new_row = row_d.copy()
        new_row['month'] = row['month']
        new_row['mentions before'] = row['mentions before']
        new_row['mentions after'] = row['mentions after']
        new_row['normalized mentions before'] = row['normalized mentions before']
        new_row['normalized mentions after'] = row['normalized mentions after']
        new_row['total posts after'] = row['total posts after']
        new_row['total posts before'] = row['total posts before']
        new_row['upvotes after'] = row['upvotes after']
        new_row['upvotes before'] = row['upvotes before']
        new_sales = new_sales.append(new_row)
    else:
      new_sales = new_sales.append(row.copy())
  
  new_sales = new_sales.loc[:, ~new_sales.columns.str.contains('^Unnamed')]
  new_sales.to_csv('game_mentions_platform_split.csv', index=False)

if __name__ == "__main__":
  try:
    main()
  except:
    type, value, tb = sys.exc_info()
    traceback.print_exc()
    pdb.post_mortem(tb)