//
//  SearchTab.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI

struct SearchTab: View {
    @State private var searchText = ""
    @State private var searchItems: [SearchItem] = []
    @State private var isLoading = false
    @State private var selectedFilter: SearchFilter = .channels
    @State private var showSuggestions = false
    @State private var suggestions: [String] = []
    
    var body: some View {
        NavigationStack {
            List {
                if searchItems.isEmpty && !isLoading && !searchText.isEmpty {
                    ContentUnavailableView.search
                } else {
                    ForEach(searchItems) { item in
                        SearchItemRow(item: item)
                    }
                    
                    if isLoading {
                        ProgressView()
                            .controlSize(.large)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(text: $searchText, prompt: "Search videos, channels, playlists...")
            .navigationDestinations()
            .onSubmit(of: .search) {
                Task {
                    await performSearch()
                }
            }
            .task(id: selectedFilter) {
                guard !searchText.isEmpty else { return }
                await performSearch()
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(SearchFilter.allCases, id: \.self) { filter in
                        Label(filter.displayName, systemImage: filter.iconName)
                            .tag(filter)
                    }
                }
                .frame(maxWidth: 250)
                .pickerStyle(.palette)
//                .controlSize(.large)
            }
        }
        .navigationLinkIndicatorVisibility(.hidden)
    }
    
    @MainActor
    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchItems = []
            return
        }
        
        isLoading = true
        let results = await PipedAPI.shared.search(query: searchText, filter: selectedFilter)
        searchItems = results
        isLoading = false
    }
}
