# Air-Quality-Data-Sonification

Air Qality Data Sonification is a project to make air pollution audible.

It makes use of R to scrape Air Pollution Data from [SENSOR.COMMUNITY](https://sensor.community) and SuperCollider to make the data audible.

## Usage

The File *scrape_sensor-community.R* provides two functions to create data sets. It scrapes the data from [archive.sensor.community](https://archive.sensor.community/).

```R
create_set_inherit(id, type, start, end)
create_set_moving_mean(id, type, start, end, dt, tmean)
```

- **id:** Sensor number, eg. *5710*
- **type:** Sensor type, eg *sds011*
- **start** Start timestemp, eg. *2021-09-01 08:00:00*
- **end** End timestemp, eq. *2021-09-01 16:15:31*
- **dt** Timestep (in s) in created Set, eq. *3600*
- **tmean** Time intervall (in s) to calculate moving mean over, eq *60*

## Examples

## Contibuting
Fell free to edit the code and pull request your ideas.

## License

1. **Data .csv files provided in the 'Examples' Directory**
> The archive.sensor.community data is made available under the Open Database License: <http://opendatacommons.org/licenses/odbl/1.0/>. Any rights in individual contents of the database are licensed under the Database Contents License: <http://opendatacommons.org/licenses/dbcl/1.0/>
2. **All other Files**
>Air Quality Data Sonification
>Copyright (C) 2021  Marv934
>
>This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
>
>This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
>
> You find the GNU General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.

