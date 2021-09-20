//
//  LASWrapper.m
//  ScanKit
//
//  Created by Kenneth Schröder on 20.09.21.
//

#import "LASWrapper.h"
#include "../LAS/include/LASlib/lasdefinitions.hpp"
#include "../LAS/include/LASlib/laspoint.hpp"
#include "../LAS/include/LASlib/laszip.hpp"
#include "../LAS/include/LASlib/laswriter.hpp"
#include "../LAS/include/LASlib/lasreader.hpp" // can import c++ headers here, in Objective-C++ code


@interface LASwriter_oc ()
{
    LASwriteOpener writeOpener;
}
@end

@implementation LASwriter_oc

-(void)write_lasFile:(ParticleUniforms[])points ofSize:(int)length toFileNamed:(const char *)name
{
    LASwriter* lasWriter;
    LASheader header;
    writeOpener.set_file_name(name);
    // printf(name);
    
    // LAS format https://www.asprs.org/a/society/committees/standards/asprs_las_format_v12.pdf or https://www.asprs.org/wp-content/uploads/2010/12/LAS_1_4_r13.pdf
    strcpy( header.file_signature, "LASF" );
    header.file_source_ID = 0; // free to assign any valid number
    // header.global_encoding = 0; // GPS Time Type "not set"
    
    header.version_major = 1;
    header.version_minor = 2; // indicating LAS version
    
    strcpy( header.system_identifier, "APPLE" );
    strcpy( header.generating_software, "ARKit4" ); // might not need those
    
    // header.header_size;
    // header.offset_to_point_data; // number of bytes from beginning of file until point data starts - relevant when using variable length records
    // header.number_of_variable_length_records = 0;
    header.point_data_format = 2; // base + RGB (= legacy for CloudCompare?) -> see UpdateMinPointFormat from https://github.com/CloudCompare/CloudCompare/blob/8b69f016884e69dbf98ab15a397a08a70149224c/plugins/core/IO/qPDALIO/include/LASFields.h
    header.point_data_record_length = header.point_data_format == 0 ? 20 : 26; // GetFormatRecordLength from https://github.com/CloudCompare/CloudCompare/blob/8b69f016884e69dbf98ab15a397a08a70149224c/plugins/core/IO/qPDALIO/include/LASFields.h
    // header.number_of_point_records = length; // might not need this
    // header.number_of_points_by_return = length; // might not need this
    header.x_scale_factor = 0.001; // coordinates are stored as longs and no floats!, need to specify a scaling factor here
    header.y_scale_factor = 0.001;
    header.z_scale_factor = 0.001;
    
    header.x_offset = 0;
    header.y_offset = 0;
    header.z_offset = 0;

    //header.max_x = 100000; // might not need those
    //header.max_y = 100000;
    //header.max_z = 100000;
    //header.min_x = -100000;
    //header.min_y = -100000;
    //header.min_z = -100000;
    
    lasWriter = writeOpener.open(&header);
    
    if (!lasWriter)
    {
        printf("Something went wrong when trying to write the file");
        // TODO: return here?
    }
    
    LASpoint lasPoint;
    lasPoint.init(&header, header.point_data_format, header.point_data_record_length, &header);
    
    for(int i = 0; i < length; i++)
    {
        lasPoint.set_R(UInt16(points[i].color[0]*255) * 256 ); // TODO: bit shifting should work as well
        lasPoint.set_G(UInt16(points[i].color[1]*255) * 256 );
        lasPoint.set_B(UInt16(points[i].color[2]*255) * 256 );
        
        UInt8 classfctn = 0;
        if(points[i].type > 1){
            classfctn |= 1 << 7; // set bit 7 (withheld)
        }
        
        switch(int(points[i].confidence)){
            case 0:
                classfctn |= 13; // low confidence, reserved LAS class
                break;
            case 1:
                classfctn |= 14; // medium confidence, reserved LAS class
                break;
            case 2:
                classfctn |= 15; // high confidence, reserved LAS class
                break;
            default: // unclassified
                break;
        }
        
        
        //lasPoint.set_intensity(0);              // pulse return magnitude.
        //lasPoint.set_return_number(0);          // the pulse return number for a given output pulse.
        //lasPoint.set_number_of_returns(0);      // total number of returns for a given pulse.
        //lasPoint.set_scan_direction_flag(0);    // direction at which the scanner mirror was traveling at the time of the output pulse.
        //lasPoint.set_edge_of_flight_line(0);    // has a value of 1 only when the point is at the end of a scan.
        lasPoint.set_classification(classfctn);   // If a point has never been classified, this byte must be set to zero.
        //lasPoint.set_scan_angle_rank(0);        // is the angle at which the laser point was output from the laser system including the roll of the aircraft.
        //lasPoint.set_user_data(0);              // may be used at the user’s discretion.
        //lasPoint.set_point_source_ID(0);        // indicates the file from which this point originated.
        
        lasPoint.set_X((points[i].position[0] + header.x_offset ) / header.x_scale_factor);
        lasPoint.set_Y((points[i].position[1] + header.y_offset ) / header.y_scale_factor);
        lasPoint.set_Z((points[i].position[2] + header.z_offset ) / header.z_scale_factor);
        
        lasWriter->write_point(&lasPoint);
        lasWriter->update_inventory(&lasPoint);
    }
    
    lasWriter->close();
}

@end
