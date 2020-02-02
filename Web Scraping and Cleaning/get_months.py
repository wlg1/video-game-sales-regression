### Adds on a months column
#Input: game_mentions_data.csv
#Outputs: game_mentions_data_months.csv

import pandas as pd
import calendar
import pdb, traceback, sys

def main():
  sales = pd.read_csv("game_mentions_data.csv")
  new_sales = pd.DataFrame(columns=sales.columns)
  months_lst = []
  for g, game in enumerate(sales['Name']):
    new_row = sales.loc[[g]]
    month = int(sales['release date'][g].split('/')[0])
    months_lst.append(calendar.month_abbr[month])
    new_sales = new_sales.append(new_row)
  new_sales['month'] = months_lst
  new_sales = new_sales.loc[:, ~new_sales.columns.str.contains('^Unnamed')]
  new_sales.to_csv('game_mentions_data_months.csv', index=False)

if __name__ == "__main__":
  try:
    main()
  except:
    type, value, tb = sys.exc_info()
    traceback.print_exc()
    pdb.post_mortem(tb)