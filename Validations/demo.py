from Read import XmlListConfig,XmlDictConfig
import xml.etree.ElementTree as ET
import pandas as pd
Path = "Converted\wwa_inttrs_Original_booking_request .xml"
tree = ET.parse(Path)
root = tree.getroot()

xmldict = XmlDictConfig(root)
file_name = 'MarksData.xlsx'
your_df_from_dict=pd.DataFrame.from_dict(xmldict,orient='index')
print(your_df_from_dict.to_excel(file_name))
