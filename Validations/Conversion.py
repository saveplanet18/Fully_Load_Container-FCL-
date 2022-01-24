import os
from lxml import etree as ET
import csv
import requests


class Conversion:

    def Conversion():
        path_xml = './xml_file/'
        path_xsl = "./xsl_file/"
        for xmlfile in os.listdir(path_xml):
            if not xmlfile.endswith('.xml'): continue
            fullpath = os.path.join(path_xml, xmlfile)
            xml = ET.parse(fullpath)
        for xslfile in os.listdir(path_xsl):
            if not xslfile.endswith('.xsl'): continue
            allfile = os.path.join(path_xsl, xslfile)
            xslt = ET.parse(allfile)
            transform = ET.XSLT(xslt)
            newdom = transform(xml)
            tree = newdom.getroot()
            Element=None
            for ele in tree.iter("BookingDetails"):
                Element =ele
            child = ET.Element("BookingNumber")
            subchile = ET.Element("WWAReference")
            subchile.text=''
            child.text = ''
            Element.insert(10,child)
            Element.insert(11,subchile)
            output =os.path.join("Converted",xmlfile)
            convert =open(output, 'w')
            convert.write(str(newdom))
            convert.close()

    if __name__ == '__main__':

        Conversion()


        

    
