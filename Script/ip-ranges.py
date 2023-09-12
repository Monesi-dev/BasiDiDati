def generate():
    with open('asn-country-ipv4.csv', 'r') as file_in, open('ip-ranges.sql', 'w') as file_out:
        for line_in in file_in:
            # Ip Start, Ip End, Country code
            ip_start, ip_end, country_code = line_in.split(',')
            ip_start = ip_start.strip()
            ip_end = ip_end.strip()
            country_code = country_code.strip()
            assert len(country_code) == 2
            country_code = country_code.upper()
            line = f'CALL `IpRangeProvaInserireAdesso`(Ip2Int(\'{ip_start}\'), Ip2Int(\'{ip_end}\'), \'{country_code}\');\n'
            file_out.write(line)
                

if __name__ == '__main__':
    generate()