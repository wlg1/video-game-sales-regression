### Combines games with the same name and release date into one row
#Input: games_w_rldates.csv
#Outputs: games_w_rldates_comb.csv

import pandas as pd
import pdb, traceback, sys

def main():
  sales = pd.read_csv("games_w_rldates.csv")
  new_sales = pd.DataFrame(columns=sales.columns)
  blacklisted_rows = []
  for g, game in enumerate(sales['Name']):
    if g in blacklisted_rows:
      continue
    
    new_row = sales.loc[[g]]
    dups = sales[sales['Name'] == game]
    if not dups.empty:
      print(g, game)
      NA_Sales = [sales['NA_Sales'][g]]
      EU_Sales = [sales['EU_Sales'][g]]
      JP_Sales = [sales['JP_Sales'][g]]
      Other_Sales = [sales['Other_Sales'][g]]
      Global_Sales = [sales['Global_Sales'][g]]
      Critic_Score = [sales['Critic_Score'][g]]
      Critic_Count = [sales['Critic_Count'][g]]
      if sales['User_Score'][g] == 'tbd':
        User_Score = []
      else:  
        User_Score = [float(sales['User_Score'][g])]
      User_Count = [sales['User_Count'][g]]
      for g2, row in dups.iterrows():
        if sales['release date'][g] == dups['release date'][g2]:
          blacklisted_rows.append(g2)
          NA_Sales.append(dups['NA_Sales'][g2])
          EU_Sales.append(dups['EU_Sales'][g2])
          JP_Sales.append(dups['JP_Sales'][g2])
          Other_Sales.append(dups['Other_Sales'][g2])
          Global_Sales.append(dups['Global_Sales'][g2])
          Critic_Score.append(dups['Critic_Score'][g2])
          Critic_Count.append(dups['Critic_Count'][g2])
          if dups['User_Score'][g2] == 'tbd':
            User_Score.append(0)
          else:  
            User_Score.append(float(dups['User_Score'][g2]))
          User_Count.append(dups['User_Count'][g2])

      new_row['NA_Sales'] = sum(NA_Sales)
      new_row['EU_Sales'] = sum(EU_Sales)
      new_row['JP_Sales'] = sum(JP_Sales)
      new_row['Other_Sales'] = sum(Other_Sales)
      new_row['Global_Sales'] = sum(Global_Sales)
      new_row['Critic_Score'] = sum(Critic_Score) / len(Critic_Score)
      new_row['Critic_Count'] = sum(Critic_Count)
      new_row['User_Score'] = sum(User_Score) / len(User_Score)
      new_row['User_Count'] = sum(User_Count)
    new_sales = new_sales.append(new_row)

  new_sales.to_csv('games_w_rldates_comb.csv', index=False)

if __name__ == "__main__":
  try:
    main()
  except:
    type, value, tb = sys.exc_info()
    traceback.print_exc()
    pdb.post_mortem(tb)