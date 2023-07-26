package main

import (
	"flag"
	"os"
	"time"

	"github.com/gdamore/tcell/v2"
	"github.com/go-resty/resty/v2"
	"github.com/rivo/tview"
	"github.com/tidwall/gjson"
)

func printHeader(table *tview.Table) {
	header := []string{"peer_id", "last_seen_p2p_address", "state", "direction"}
	for i, col := range header {
		table.SetCell(0, i, &tview.TableCell{
			Text:            col,
			Color:           tcell.ColorBlack,
			BackgroundColor: tcell.ColorGreen,
		})
	}
}

func printData(table *tview.Table, data gjson.Result) {
	row := 1
	data.ForEach(func(_, value gjson.Result) bool {
		state := value.Get("state").String()
		if state != "connected" {
			return true
		}
		// Skip enr for now. It is display unfriendly, and only appears on a few nodes
		peerID := value.Get("peer_id").String()
		lastSeenP2PAddress := value.Get("last_seen_p2p_address").String()
		direction := value.Get("direction").String()

		line := []string{peerID, lastSeenP2PAddress, state, direction}
		for i, col := range line {
			table.SetCell(row, i, &tview.TableCell{
				Text:            col,
				Color:           tcell.ColorGreen,
				BackgroundColor: tcell.ColorBlack,
			})
		}
		row++
		return true
	})
}

func main() {
	endPointPtr := flag.String("endpoint", "http://127.0.0.1:3500", "endpoint URL")
	flag.Parse()

	app := tview.NewApplication()
	table := tview.NewTable().SetBorders(true)
	table.Select(0, 0).SetFixed(1, 1).SetDoneFunc(func(key tcell.Key) {
		if key == tcell.KeyCtrlC {
			app.Stop()
			os.Exit(0)
		}
	})

	app.SetRoot(table, true)

	client := resty.New()
	go func() {
		for {
			// https://ethereum.github.io/beacon-APIs/#/Node/getPeers
			resp, err := client.R().Get(*endPointPtr + "/eth/v1/node/peers")
			if err != nil {
				panic(err)
			}

			data := gjson.Get(string(resp.Body()), "data")

			table.Clear()
			printHeader(table)
			printData(table, data)

			app.Draw()

			// refresh every 2 seconds
			time.Sleep(2 * time.Second)
		}
	}()

	if err := app.Run(); err != nil {
		panic(err)
	}
}
