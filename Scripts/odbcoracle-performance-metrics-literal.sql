-- Execute query to see the performance statistics using literal variables.

SET FEEDBACK OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 300;
SET TRIMOUT ON;
SET TRIMSPOOL ON;

DECLARE
        TYPE rc IS REF CURSOR;
        l_rc rc;
        l_description char(100);
        l_start timestamp := systimestamp;
    BEGIN
        FOR i IN 1 .. 1000 LOOP            
            OPEN l_rc FOR            
                'SELECT F157033K1
                 FROM VWBPLIBF.VTLI0049
                 WHERE F157033K2 = ' || i;
            FETCH l_rc INTO l_description;
            CLOSE l_rc;            
        END LOOP;

        dbms_output.put_line('ODBCORACLE, Literal, ' ||
            to_number(to_char( to_timestamp( trunc( sysdate ) ) + ( systimestamp- l_start ), 'ff3' )));
    END;
/

EXIT;

