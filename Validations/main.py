import os
from xml_parser import xmlreader
import xml.etree.ElementTree as ET

def main():
    try:
        path = 'Converted\wwa_inttrs_Original_booking_request .xml'
        root =xmlreader.read_xml_file(os.path.join(path))
        return root
    except Exception as err:
            if type(err) == ET.ParseError:
                message = 'The XML is not well formed'
            else:
                message = err
            return message
     
if __name__ == '__main__':
    print(main())


