import Foundation
import SwiftData

// MARK: - Mock Mucks

extension Muck {
    static var mockData: [Muck] {[
        Muck(
            id: "MK-1001",
            location: "Princes Park, Melbourne",
            description: "Large pile of dumped rubbish near the oval entrance. Includes old furniture and plastic bags.",
            type: .cleanup,
            reportedDate: Calendar.current.date(byAdding: .day, value: -3, to: .now)!,
            latitude: -37.7740,
            longitude: 144.9590,
            votes: 24,
            eventCount: 1
        ),
        Muck(
            id: "MK-1002",
            location: "Merri Creek Trail, Northcote",
            description: "Broken glass and syringes scattered along the footpath. Hazardous to pedestrians and dogs.",
            type: .hazard,
            isHazardous: true,
            reportedDate: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
            latitude: -37.7640,
            longitude: 145.0010,
            votes: 41,
            eventCount: 0
        ),
        Muck(
            id: "MK-1003",
            location: "Brunswick Street, Fitzroy",
            description: "Graffiti covering the heritage bluestone wall outside the library. Needs community removal.",
            type: .cleanup,
            reportedDate: Calendar.current.date(byAdding: .day, value: -7, to: .now)!,
            latitude: -37.7969,
            longitude: 144.9778,
            votes: 15,
            eventCount: 2
        ),
        Muck(
            id: "MK-1004",
            location: "Yarra River Bank, Richmond",
            description: "Damaged park bench with exposed nails along the riverside walk. Trip hazard.",
            type: .repair,
            reportedDate: Calendar.current.date(byAdding: .day, value: -5, to: .now)!,
            latitude: -37.8230,
            longitude: 145.0050,
            votes: 9,
            eventCount: 0
        ),
        Muck(
            id: "MK-1005",
            location: "Elwood Beach, St Kilda",
            description: "Significant litter accumulation along the shoreline after weekend storms. Mostly plastic bottles.",
            type: .cleanup,
            reportedDate: Calendar.current.date(byAdding: .hour, value: -6, to: .now)!,
            latitude: -37.8850,
            longitude: 144.9890,
            votes: 33,
            eventCount: 1
        ),
        Muck(
            id: "MK-1006",
            location: "Royal Park, Parkville",
            description: "Broken playground equipment — slide has a cracked section that could injure children.",
            type: .repair,
            reportedDate: Calendar.current.date(byAdding: .day, value: -2, to: .now)!,
            latitude: -37.7870,
            longitude: 144.9568,
            votes: 18,
            eventCount: 0
        ),
        Muck(
            id: "MK-1007",
            location: "Moonee Ponds Creek, Essendon",
            description: "Industrial waste drums partially submerged in the creek. Possible chemical contamination.",
            type: .hazard,
            isHazardous: true,
            reportedDate: Calendar.current.date(byAdding: .day, value: -4, to: .now)!,
            latitude: -37.7520,
            longitude: 144.9230,
            votes: 62,
            eventCount: 0
        ),
        Muck(
            id: "MK-1008",
            location: "Capital City Trail, Clifton Hill",
            description: "Fly-tipped mattresses and building rubble blocking the bike path.",
            type: .cleanup,
            reportedDate: Calendar.current.date(byAdding: .day, value: -6, to: .now)!,
            latitude: -37.7880,
            longitude: 144.9940,
            votes: 27,
            eventCount: 1
        ),
    ]}
}

// MARK: - Mock Events

extension MuckEvent {
    static var mockData: [MuckEvent] {[
        MuckEvent(
            id: 5001,
            title: "Princes Park Cleanup Morning",
            location: "Princes Park, Melbourne",
            date: Calendar.current.date(byAdding: .day, value: 5, to: .now)!,
            description: "Join us for a Saturday morning litter pickup. Bags and gloves provided. Meet at the main oval gates.",
            muckIds: ["MK-1001"],
            participants: 12,
            isAttending: false
        ),
        MuckEvent(
            id: 5002,
            title: "Elwood Beach Blitz",
            location: "Elwood Beach, St Kilda",
            date: Calendar.current.date(byAdding: .day, value: 10, to: .now)!,
            description: "Post-storm beach cleanup. Targeting plastic bottles and packaging washed up overnight.",
            muckIds: ["MK-1005"],
            participants: 28,
            isAttending: true
        ),
        MuckEvent(
            id: 5003,
            title: "Capital City Trail Rubbish Run",
            location: "Clifton Hill",
            date: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
            description: "Clear the mattresses and rubble from the trail. Council skip bin will be on-site.",
            muckIds: ["MK-1008"],
            participants: 7,
            isAttending: false
        ),
    ]}
}

// MARK: - Mock Help Requests

extension HelpRequest {
    static var mockData: [HelpRequest] {
        let items = [
            HelpRequest(
                id: "HLP-1001",
                title: "Overgrown yard needs a working bee",
                description: "Yard hasn't been touched in months — grass is knee-high and there's a fallen branch blocking the side path. Could use 2-3 people for a few hours.",
                category: .yardWork,
                preferredDate: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
                exactLatitude: -37.7860,
                exactLongitude: 144.9700,
                requesterId: "demo-neighbour-1"
            ),
            HelpRequest(
                id: "HLP-1002",
                title: "Help moving a couch downstairs",
                description: "Moving out this weekend and need a hand getting a heavy couch and a few boxes down two flights of stairs.",
                category: .moving,
                preferredDate: Calendar.current.date(byAdding: .day, value: 5, to: .now)!,
                exactLatitude: -37.8010,
                exactLongitude: 144.9820,
                requesterId: "demo-neighbour-2"
            ),
            HelpRequest(
                id: "HLP-1003",
                title: "Fence panel blew down in the storm",
                description: "One fence panel came loose in last night's wind. Just needs re-screwing to the post — have the tools, just need an extra pair of hands to hold it steady.",
                category: .repairs,
                preferredDate: Calendar.current.date(byAdding: .day, value: 1, to: .now)!,
                exactLatitude: -37.7920,
                exactLongitude: 144.9550,
                requesterId: "demo-neighbour-3"
            ),
        ]
        return items
    }
}

// MARK: - Mock Partner Items

extension PartnerItem {
    static var mockData: [PartnerItem] {[
        PartnerItem(
            id: "TM-001",
            name: "Brunswick Litter Warriors",
            organisation: "TrashMob",
            source: .trashmob,
            latitude: -37.7740,
            longitude: 144.9590,
            date: Calendar.current.date(byAdding: .day, value: 4, to: .now),
            itemDescription: "Monthly neighbourhood pickup. All welcome — bring your own gloves.",
            externalURL: URL(string: "https://www.trashmob.eco")!,
            attendees: 15
        ),
        PartnerItem(
            id: "OLM-001",
            name: "Plastic bottles — Merri Creek",
            organisation: "OpenLitterMap",
            source: .openlittermap,
            latitude: -37.7640,
            longitude: 145.0010,
            date: Calendar.current.date(byAdding: .day, value: -1, to: .now),
            itemDescription: "12 plastic bottles and assorted packaging observed along the creek bank.",
            externalURL: URL(string: "https://openlittermap.com")!,
            litterType: "Plastic"
        ),
        PartnerItem(
            id: "EPA-001",
            name: "Hazardous Waste Site — Coburg",
            organisation: "EPA Envirofacts",
            source: .epa,
            latitude: -37.7430,
            longitude: 144.9630,
            date: nil,
            itemDescription: "RCRA-listed hazardous waste facility. Requires specialist remediation.",
            externalURL: URL(string: "https://enviro.epa.gov")!
        ),
        PartnerItem(
            id: "WCD-001",
            name: "World Cleanup Day — Southbank",
            organisation: "World Cleanup Day",
            source: .wcd,
            latitude: -37.8220,
            longitude: 144.9640,
            date: Calendar.current.date(byAdding: .day, value: 12, to: .now),
            itemDescription: "Global event — local Southbank chapter. Register to join the worldwide count.",
            externalURL: URL(string: "https://www.worldcleanupday.org")!,
            attendees: 45
        ),
        PartnerItem(
            id: "JS-001",
            name: "Scouts Environment Blitz",
            organisation: "JustServe",
            source: .justserve,
            latitude: -37.8100,
            longitude: 144.9700,
            date: Calendar.current.date(byAdding: .day, value: 7, to: .now),
            itemDescription: "Local Scouts group running a park restoration morning. Families welcome.",
            externalURL: URL(string: "https://www.justserve.org")!,
            attendees: 22
        ),
        PartnerItem(
            id: "VC-001",
            name: "Creek Restoration Volunteer Day",
            organisation: "VolunteerConnector",
            source: .volunteerconnector,
            latitude: -37.7900,
            longitude: 144.9800,
            date: Calendar.current.date(byAdding: .day, value: 9, to: .now),
            itemDescription: "Native planting and litter removal along the Darebin Creek corridor.",
            externalURL: URL(string: "https://www.volunteerconnector.org")!,
            attendees: 18
        ),
    ]}
}

// MARK: - SwiftData Preview Container

@MainActor
let previewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Muck.self, MuckEvent.self, HelpRequest.self, configurations: config)

    for muck in Muck.mockData {
        container.mainContext.insert(muck)
    }
    for event in MuckEvent.mockData {
        container.mainContext.insert(event)
    }
    for request in HelpRequest.mockData {
        container.mainContext.insert(request)
    }

    return container
}()
