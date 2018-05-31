# nagios-plugin-check_zway2

## check_zway2

### EN

Nagios Plugin to read values and check the status of your switches, sensors, 
etc. out of the Z-Way HomeAutomation System using the JSON API.

Currently the following CommandClasses are supported:

- 37 - SwitchBinary
- 38 - SwitchMultilevel
- 49 - MultiSensor
- 50 - Meter / MultiSensor
- 67 - Thermostat
- 113 - SensorBinary
- 128 - Battery

With the values and the status, performance values will be provided too. 
Using these performance values, it is easy to provide long-term statistics.


### DE
Nagios Plugin zum Auslesen der Werte und Testen des Status von Schaltern, 
Sensoren, usw. aus dem Z-Way HomeAutomation System mit Hilfe der JSON API.

Aktuell sind die folgenden Command-Klassen unterstützt:

- 37 - SwitchBinary
- 38 - SwitchMultilevel
- 49 - MultiSensor
- 50 - Meter / MultiSensor
- 67 - Thermostat
- 113 - SensorBinary
- 128 - Battery

Zusätzlich zum Messwert bzw. Status werden Performancedaten bereitgestellt. 
Hiermit kann eine Langzeitstatistik mit Nagios realisiert werden.


### Usage

check_zway2 -u|--url <http://host:port/url> -a|--attributes <attributes>
     -c|--critical <thresholds> 
     -w|--warning <thresholds>  
     -U|--ZWayUser 
     -P|--ZWayPassword 
     -D|--ZWayDevice 
     -I|--ZWayInstance  (default:0)
     -C|--ZWayCommandClass 
     -M|--ZWayMeter 
     -t|--timeout <timeout> 
     --ignoressl 
     -h|--help 


