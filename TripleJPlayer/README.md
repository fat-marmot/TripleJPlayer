# Triple J API Endpoints

## Current Track
https://music.abcradio.net.au/api/v1/plays/triplej/now.json?tz=Australia%2FSydney
- Provides currently playing track and previous track

## Track History
https://music.abcradio.net.au/api/v1/plays/search.json?station=triplej&order=desc&tz=Australia%2FSydney&limit=22
- Provides extensive play history
- Can adjust 'limit' parameter for more or fewer tracks
- Use for displaying recent play history

## Program Information
https://program.abcradio.net.au/api/v1/programitems/search.json?include=next%2Cwith_images%2Cresized_images&service=triplej&from=[DATE]&to=[DATE]&order_by=ppe_date&order=asc&limit=50
- Contains show/program information
- Add date parameters in format: 2025-04-18T01%3A00%3A00
